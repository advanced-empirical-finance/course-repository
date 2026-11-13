-- The PDF version of the decks (format: beamer). Reveal.js shows some parts
-- interactively; the PDF puts them on plain slides instead:
-- - a tabset (R | Python) becomes one slide per tab, e.g. "Reading the data (R)";
-- - the output of a cell with output-location: slide goes on the next slide;
-- - a timeline becomes a table of dates and events;
-- - an iframe is left out, so the slide needs a link next to it;
-- - every slide shrinks its content if it would not fit on the page.
-- Other formats are left as they are.

local slide        -- header of the current slide
local continued = 0

local function new_slide(suffix)
  continued = continued + 1
  local title = slide.content:clone()
  if suffix then
    title:insert(pandoc.Str(" (" .. suffix .. ")"))
  end
  return pandoc.Header(2, title, pandoc.Attr(slide.identifier .. "-" .. continued, { "shrink" }))
end

-- A cell with output-location: slide keeps its code here and moves its output
-- to a slide of its own.
local function split_cell(block, suffix)
  if not (block.t == "Div" and block.classes:includes("cell")
          and block.attributes["output-location"] == "slide") then
    return { block }
  end
  local code, output = pandoc.Blocks {}, pandoc.Blocks {}
  for _, part in ipairs(block.content) do
    if part.t == "CodeBlock" then code:insert(part) else output:insert(part) end
  end
  block.attributes["output-location"] = nil
  local result = { pandoc.Div(code, block.attr) }
  if #output > 0 and slide then
    result[#result + 1] = new_slide(suffix)
    result[#result + 1] = pandoc.Div(output, block.attr)
  end
  return result
end

local function tabs_of(tabset)
  local level = math.huge
  for _, block in ipairs(tabset.content) do
    if block.t == "Header" then level = math.min(level, block.level) end
  end
  local tabs = {}
  for _, block in ipairs(tabset.content) do
    if block.t == "Header" and block.level == level then
      tabs[#tabs + 1] = { name = pandoc.utils.stringify(block), content = pandoc.Blocks {} }
    elseif #tabs > 0 then
      tabs[#tabs].content:insert(block)
    end
  end
  return tabs
end

local function timeline_table(timeline)
  local rows = {}
  for _, event in ipairs(timeline.content) do
    if event.t == "Div" then
      local label = event.attributes["data-label"] or event.attributes["label"] or ""
      local text = pandoc.Inlines {}
      for _, part in ipairs(event.content) do
        if part.content then
          if #text > 0 then text:insert(pandoc.Str(" – ")) end
          text:extend(part.content)
        end
      end
      rows[#rows + 1] = { { pandoc.Plain { pandoc.Str(label) } }, { pandoc.Plain(text) } }
    end
  end
  local simple = pandoc.SimpleTable({}, { pandoc.AlignLeft, pandoc.AlignLeft }, { 0, 0 }, {}, rows)
  return pandoc.utils.from_simple_table(simple)
end

function Pandoc(doc)
  if not quarto.doc.is_format("beamer") then return nil end
  local blocks = pandoc.Blocks {}
  local slide_index
  for _, block in ipairs(doc.blocks) do
    if block.t == "Header" and block.level == 2 then
      block.classes:insert("shrink")
      slide, slide_index = block, #blocks + 1
      blocks:insert(block)
    elseif block.t == "Header" and block.level == 1 then
      slide = nil
      blocks:insert(block)
    elseif block.t == "Div" and block.classes:includes("panel-tabset") then
      for i, tab in ipairs(tabs_of(block)) do
        if not slide then
          blocks:extend(tab.content)
        else
          if i == 1 then
            local title = slide.content:clone()
            title:insert(pandoc.Str(" (" .. tab.name .. ")"))
            blocks[slide_index] = pandoc.Header(2, title, slide.attr)
          else
            blocks:insert(new_slide(tab.name))
          end
          for _, part in ipairs(tab.content) do
            blocks:extend(split_cell(part, tab.name))
          end
        end
      end
    elseif block.t == "Div" and block.classes:includes("timeline") then
      blocks:insert(timeline_table(block))
    elseif block.t == "RawBlock" and block.format == "html" and block.text:match("<iframe") then
      -- left out: an iframe cannot be shown in a PDF
    else
      blocks:extend(split_cell(block))
    end
  end
  doc.blocks = blocks
  return doc
end
