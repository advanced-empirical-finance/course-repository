# /// script
# requires-python = ">=3.11"
# dependencies = ["torch", "polars", "numpy", "pyarrow", "tidyfinance"]
# ///
"""A light version of Chen, Pelger & Zhu (2024), "Deep learning in asset pricing",
on the factor zoo: the running example of the ML lectures (course-homepage#16).

The SDF is M_{t+1} = 1 - sum_i w_{t,i} R_{t+1,i}. A feed-forward network maps the
macro state and each anomaly's own features to its weight w_{t,i}. An adversarial
network builds test assets g(I_t, I_{t,i}); the SDF network minimizes the pricing
errors of the moment conditions E[M_{t+1} R_{t+1,i} g(I_t, I_{t,i})] = 0, and the
adversary picks the g with the largest errors. "Light": the macro state is the
current value of five Goyal-Welch predictors instead of LSTM states.

Samples: training 1974-1994, validation 1995-1999 (early stopping), test 2000-2023.

Run from the course repository: uv run lecture-slides/factor-zoo/cpz_light.py
It uses a GPU if one is available. Results go to lecture-slides/factor-zoo/results/.
"""
import argparse
from pathlib import Path

import numpy as np
import polars as pl
import tidyfinance as tf
import torch
from torch import nn

parser = argparse.ArgumentParser()
parser.add_argument("--seeds", type=int, default=5, help="networks in the ensemble")
parser.add_argument("--hidden", type=int, default=64, help="units per hidden layer")
parser.add_argument("--instruments", type=int, default=8, help="test assets per anomaly (adversary)")
parser.add_argument("--rounds", type=int, default=3, help="adversarial rounds")
parser.add_argument("--pcs", type=int, default=10, help="principal-component loadings as anomaly features")
parser.add_argument("--no-macro", action="store_true", help="leave out the macro state")
parser.add_argument("--dropout", type=float, default=0.05)
parser.add_argument("--weight-decay", type=float, default=1e-5)
parser.add_argument("--lr", type=float, default=1e-3)
parser.add_argument("--patience", type=int, default=100, help="steps without validation improvement before stopping")
args = parser.parse_args()

device = "cuda" if torch.cuda.is_available() else "cpu"
torch.set_num_threads(max(1, torch.get_num_threads()))

# Data -----------------------------------------------------------------------
osap_file = Path("data/osap_long_short_returns.parquet")
if not osap_file.exists():
    pl.read_parquet(
        "https://huggingface.co/datasets/OpenSourceAP/CrossSection/resolve/"
        "Data-Release-2026.10/Portfolios/Full%20Sets%20OP/PredictorLSretWide.parquet"
    ).write_parquet(osap_file)

anomalies = (pl.read_parquet(osap_file)
    .with_columns(pl.col("date").dt.truncate("1mo"))
    .filter(pl.col("date").is_between(pl.date(1973, 1, 1), pl.date(2023, 12, 31)))
    .sort("date")
)
complete = [c for c in anomalies.columns if c != "date" and anomalies[c].null_count() == 0]
dates = anomalies["date"].to_numpy()
R = anomalies.select(complete).to_numpy() / 100          # T x N monthly returns

macro_names = ["dp", "tbl", "tms", "dfy", "svar"]
macro = (tf.download_data(domain="Goyal-Welch", dataset="monthly",
                          start_date="1972-12-01", end_date="2023-12-31")
    .with_columns(pl.col("date").dt.offset_by("1mo"))     # known at the end of the previous month
    .select("date", *macro_names)
)
macro = anomalies.select("date").join(macro, on="date", how="left")
X = macro.select(macro_names).to_numpy()                 # T x 5, macro state for month t

# Anomaly features known before month t: last return, 12-month momentum, historical mean
lagged = np.vstack([np.full((1, R.shape[1]), np.nan), R[:-1]])
momentum = np.full_like(R, np.nan)
for t in range(12, R.shape[0]):
    momentum[t] = R[t - 12:t].mean(axis=0)
historical = np.full_like(R, np.nan)
for t in range(1, R.shape[0]):
    historical[t] = R[:t].mean(axis=0)
C = np.stack([lagged, momentum, historical], axis=2)     # T x N x 3

keep = ~np.isnan(C).any(axis=(1, 2)) & ~np.isnan(X).any(axis=1)
dates, R, X, C = dates[keep], R[keep], X[keep], C[keep]
train = dates < np.datetime64("1995-01-01")
valid = (dates >= np.datetime64("1995-01-01")) & (dates < np.datetime64("2000-01-01"))
test = dates >= np.datetime64("2000-01-01")

# Each anomaly's loadings on the first principal components of the training
# covariance. The MVE weights depend on how an anomaly co-moves with all others;
# with the loadings, even a linear network can reproduce the PCA SDF.
if args.pcs > 0:
    values, vectors = np.linalg.eigh(np.cov(R[train], rowvar=False))
    loadings = vectors[:, np.argsort(values)[::-1][: args.pcs]]
    C = np.concatenate([C, np.repeat(loadings[None, :, :], C.shape[0], axis=0)], axis=2)

# standardize with the training sample only
X = (X - X[train].mean(0)) / X[train].std(0)
C = (C - C[train].mean((0, 1))) / C[train].std((0, 1))
T, N = R.shape
inputs = C if args.no_macro else np.concatenate([np.repeat(X[:, None, :], N, axis=1), C], axis=2)

R_t = torch.tensor(R, dtype=torch.float32, device=device)
I_t = torch.tensor(inputs, dtype=torch.float32, device=device)
masks = {name: torch.tensor(m, device=device) for name, m in
         {"train": train, "valid": valid, "test": test}.items()}


# Networks -------------------------------------------------------------------
def network(n_out, hidden, dropout=args.dropout):
    return nn.Sequential(
        nn.Linear(inputs.shape[2], hidden), nn.ReLU(), nn.Dropout(dropout),
        nn.Linear(hidden, hidden), nn.ReLU(), nn.Dropout(dropout),
        nn.Linear(hidden, n_out),
    ).to(device)


def pricing_loss(weights, instruments, mask):
    """Mean squared pricing error of the moments E[M R_i g_j] = 0 over the months in mask."""
    sdf = 1 - (weights * R_t).sum(dim=1)                                # T
    moments = (sdf[:, None, None] * R_t[:, :, None] * instruments)[mask].mean(dim=0)  # N x D
    return (moments ** 2).sum(dim=1).mean()


def sharpe(x):
    return float(x.mean() / x.std() * np.sqrt(12))


def train_sdf(seed, adversarial):
    torch.manual_seed(seed)
    sdf_net = network(1, args.hidden)
    adv_net = network(args.instruments, args.hidden)
    optimizer = torch.optim.Adam(sdf_net.parameters(), lr=args.lr, weight_decay=args.weight_decay)
    adv_optimizer = torch.optim.Adam(adv_net.parameters(), lr=args.lr)
    ones = torch.ones(T, N, 1, device=device)

    def weights(training):
        sdf_net.train(training)
        return sdf_net(I_t).squeeze(-1)

    def fit(instruments_fn, steps):
        best, best_state, patience = np.inf, None, 0
        for _ in range(steps):
            optimizer.zero_grad()
            loss = pricing_loss(weights(True), instruments_fn(), masks["train"])
            loss.backward()
            optimizer.step()
            with torch.no_grad():   # early stopping on the validation pricing errors
                valid_loss = pricing_loss(weights(False), instruments_fn(), masks["valid"]).item()
            if valid_loss < best:
                best, best_state, patience = valid_loss, {k: v.clone() for k, v in sdf_net.state_dict().items()}, 0
            else:
                patience += 1
                if patience > args.patience:
                    break
        sdf_net.load_state_dict(best_state)

    # 1. unconditional moments (g = 1)
    fit(lambda: ones, 2000)
    if adversarial:
        for _ in range(args.rounds):
            # 2. the adversary picks the test assets with the largest pricing errors
            with torch.no_grad():
                w = weights(False)
            for _ in range(200):
                adv_optimizer.zero_grad()
                g = torch.tanh(adv_net(I_t))
                (-pricing_loss(w, g, masks["train"])).backward()
                adv_optimizer.step()
            # 3. the SDF network prices these test assets (and the unconditional moments)
            adv_net.eval()
            with torch.no_grad():
                g_fixed = torch.cat([ones, torch.tanh(adv_net(I_t))], dim=2)
            fit(lambda: g_fixed, 1000)
    with torch.no_grad():
        return weights(False).cpu().numpy()


# Ensemble and scoreboard rows --------------------------------------------------
rows, sdf_returns = [], []
for adversarial, label in [(False, "B4 Feed-forward SDF (unconditional moments)"),
                           (True, "B4 Chen-Pelger-Zhu light (adversarial moments)")]:
    w = np.mean([train_sdf(seed, adversarial) for seed in range(args.seeds)], axis=0)
    portfolio = (w * R).sum(axis=1)
    rows.append({
        "model": label,
        "sr_train": sharpe(portfolio[train]),
        "sr_valid": sharpe(portfolio[valid]),
        "sr_estimation": sharpe(portfolio[train | valid]),
        "sr_test": sharpe(portfolio[test]),
    })
    sdf_returns.append(pl.DataFrame({"date": dates, "model": label, "ret": portfolio}))
    print(rows[-1], flush=True)

out = Path("lecture-slides/factor-zoo/results")
out.mkdir(parents=True, exist_ok=True)
settings = {k: str(v) for k, v in vars(args).items()}
run_id = "_".join(f"{k}-{v}" for k, v in settings.items())
scoreboard = (pl.DataFrame(rows)
    .with_columns(pl.col("^sr_.*$").round(2))
    .with_columns(**{k: pl.lit(v) for k, v in settings.items()}, device=pl.lit(device))
)
# every run appends its settings and results, so a hyperparameter search ends in one table
runs_file = out / "cpz_light_runs.csv"
if runs_file.exists():
    scoreboard = pl.concat([pl.read_csv(runs_file, infer_schema_length=0), scoreboard.cast(pl.String)], how="diagonal")
scoreboard.cast(pl.String).write_csv(runs_file)
pl.concat(sdf_returns).write_parquet(out / f"cpz_light_sdf_returns_{run_id}.parquet")
scoreboard = scoreboard.tail(2)
print(f"device: {device}, anomalies: {N}, months: {T}, seeds: {args.seeds}, pcs: {args.pcs}")
with pl.Config(tbl_width_chars=120):
    print(scoreboard)
