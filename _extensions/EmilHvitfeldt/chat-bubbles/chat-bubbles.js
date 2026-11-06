window.RevealChatBubbles = function () {
  return {
    id: "RevealChatBubbles",
    init: function (deck) {

      const SLOT_COUNT = 4;

      // Legacy authoring classes, kept as aliases for the canonical .speaker-N.
      // These are read here and nowhere else: all styling hangs off data-slot,
      // so themes never need to know that either vocabulary exists.
      const legacySlots = {
        'bubble-right': 1,
        'bubble-left': 2,
        'bubble-left-2': 3,
        'bubble-left-3': 4
      };

      function slotOf(el) {
        for (let i = 1; i <= SLOT_COUNT; i++) {
          if (el.classList.contains(`speaker-${i}`)) return i;
        }
        for (const cls in legacySlots) {
          if (el.classList.contains(cls)) return legacySlots[cls];
        }
        return null;
      }

      // Quarto rewrites non-standard attributes on a div to a data- prefix,
      // so `theme="slack"` reaches the DOM as data-theme. Accept both spellings.
      function attr(el, name) {
        return el.getAttribute(name) || el.getAttribute('data-' + name);
      }

      function splitList(value) {
        return (value || '').split(',').map(s => s.trim());
      }

      // Every message gets the same scaffolding regardless of theme, so that a
      // theme is a CSS-only addition. Themes that want no avatar simply hide it.
      function scaffold(el, name, avatarUrl) {
        const text = document.createElement('div');
        text.className = 'bubble-text';
        while (el.firstChild) text.appendChild(el.firstChild);

        const avatar = document.createElement('span');
        avatar.className = 'bubble-avatar';
        avatar.setAttribute('aria-hidden', 'true');
        if (avatarUrl) {
          avatar.style.backgroundImage = `url("${avatarUrl}")`;
          avatar.classList.add('has-image');
        } else if (name) {
          avatar.textContent = Array.from(name)[0].toUpperCase();
        }

        const label = document.createElement('span');
        label.className = 'bubble-name';
        if (name) label.textContent = name;

        const reactions = document.createElement('div');
        reactions.className = 'bubble-reactions';

        // Order matters only as a grid source order; themes place these by area.
        el.append(avatar, label, text, reactions);
      }

      // Normalize authoring markup into the canonical attributes the CSS targets.
      // Runs synchronously from init() rather than on 'ready': Reveal keeps slides
      // hidden until it is ready, so doing this early avoids a flash of unstyled
      // messages in the window before the attributes exist.
      function normalizeChat(chat) {
        const self = parseInt(attr(chat, 'self')) || 1;
        chat.dataset.selfSlot = self;

        // Copied through without a registry of known themes, so adding a theme
        // stays a CSS-only change. Normalizing to a data attribute (rather than
        // styling `theme` directly) keeps the default theme a plain value
        // instead of a chain of :not() negations that grows with each theme.
        chat.dataset.chatTheme = attr(chat, 'theme') || 'imessage';

        // Roster maps positionally onto slots: names="a,b,c" -> slots 1,2,3
        const names = splitList(attr(chat, 'names'));
        const avatars = splitList(attr(chat, 'avatars'));

        let previousSlot = null;
        Array.from(chat.children).forEach(el => {
          const slot = slotOf(el);
          if (slot === null) return;
          el.dataset.slot = slot;
          // Which slot sits on the "sender" side is a property of the conversation,
          // not of the class name, so alternating themes read this rather than
          // inferring a side from the slot number.
          if (slot === self) el.dataset.self = '';

          const name = attr(el, 'name') || names[slot - 1] || '';
          if (name) el.dataset.speaker = name;

          // Computed for every theme; only the flat ones act on it.
          if (slot === previousSlot) el.dataset.continues = '';
          previousSlot = slot;

          scaffold(el, name, avatars[slot - 1]);
        });
      }

      function isBubble(el) {
        return el.dataset.slot !== undefined;
      }

      function isReaction(el) {
        return el.classList.contains('reaction');
      }

      function isTypingReveal(el) {
        return el.classList.contains('typing-reveal');
      }

      // Animate a typing bubble between its two states (dots ↔ text).
      // Text stays invisible (opacity:0) during the size animation and fades in
      // only after the bubble reaches full size.
      // Returns the end height (useful for scroll calculations); `onSettled` runs
      // once the bubble has actually reached that height, which is when the
      // container's scrollHeight finally reflects it.
      function animateBubble(bubble, toTextRevealed, onSettled) {
        const textEl = bubble.querySelector('.bubble-text');

        // Use getBoundingClientRect for sub-pixel accurate dimensions.
        // offsetWidth/offsetHeight round to integers, which causes a visible
        // snap when the inline style is cleared back to auto.
        // Measured before cancelling any in-progress animation: _animCancel
        // clears the inline max-width/max-height override, which reverts the
        // bubble to its natural size for whatever class state is still
        // active -- not the live mid-transition size -- so reading `from`
        // after cancelling would snap to that natural size instead of
        // continuing from wherever the bubble actually is.
        let r = bubble.getBoundingClientRect();
        const from = { w: r.width, h: r.height };

        // Cancel any in-progress animation on this bubble
        if (bubble._animCancel) bubble._animCancel();

        toTextRevealed
          ? bubble.classList.add('text-revealed')
          : bubble.classList.remove('text-revealed');

        // Keep text invisible while we measure and animate the size change
        if (toTextRevealed && textEl) {
          textEl.style.transition = 'none';
          textEl.style.opacity = '0';
        }

        r = bubble.getBoundingClientRect();
        const to = { w: r.width, h: r.height };

        if (from.w === to.w && from.h === to.h) {
          // No size change — just fade the text in immediately
          if (toTextRevealed && textEl) fadeInText(textEl);
          if (onSettled) onSettled();
          return to.h;
        }

        // Use max-width/max-height rather than width/height.
        // When cleared after animation, max-width reverts to the CSS value (65%) and
        // max-height reverts to none — both of which produce the same rendered size as
        // the measured `to` dimensions (since `to` was measured under those same CSS
        // constraints). This avoids the post-animation snap caused by clearing an
        // explicit width/height whose pixel value can differ from the auto-sized result.
        // Omitting overflow:hidden also keeps the bubble tail (::after) visible throughout.
        bubble.style.maxWidth = from.w + 'px';
        bubble.style.maxHeight = from.h + 'px';
        bubble.style.transition = 'none';
        void bubble.offsetWidth; // force reflow

        bubble.style.transition = 'max-width 0.25s ease, max-height 0.25s ease';
        bubble.style.maxWidth = to.w + 'px';
        bubble.style.maxHeight = to.h + 'px';

        const expectedCount = (from.w !== to.w ? 1 : 0) + (from.h !== to.h ? 1 : 0);
        let doneCount = 0;

        function onEnd(e) {
          if (e.propertyName !== 'max-width' && e.propertyName !== 'max-height') return;
          if (++doneCount < expectedCount) return;
          bubble.removeEventListener('transitionend', onEnd);
          bubble._animCancel = null;
          bubble.style.maxWidth = '';
          bubble.style.maxHeight = '';
          bubble.style.transition = '';
          if (toTextRevealed && textEl) fadeInText(textEl);
          if (onSettled) onSettled();
        }

        bubble.addEventListener('transitionend', onEnd);

        bubble._animCancel = () => {
          bubble.removeEventListener('transitionend', onEnd);
          bubble._animCancel = null;
          bubble.style.maxWidth = '';
          bubble.style.maxHeight = '';
          bubble.style.transition = '';
          if (textEl) {
            textEl.style.opacity = '';
            textEl.style.transition = '';
          }
        };

        return to.h;
      }

      function fadeInText(textEl) {
        void textEl.offsetWidth; // force reflow so transition fires
        textEl.style.transition = 'opacity 0.15s ease';
        textEl.style.opacity = '';  // fall back to CSS (1)
        textEl.addEventListener('transitionend', () => {
          textEl.style.transition = '';
        }, { once: true });
      }

      const buffer = 150;

      // Single source of truth for "keep this message in view". Everything that
      // can change the height of the transcript — a bubble appearing, a typing
      // bubble expanding, a reaction opening a row, an image finishing its
      // decode — routes through here so the rules stay identical.
      //
      // `knownHeight` exists for callers that are mid-animation, where the
      // bubble's measured height is the *start* of a transition rather than
      // where it will end up.
      function scrollBubbleIntoView(chat, bubble, knownHeight) {
        const height = knownHeight === undefined ? bubble.offsetHeight : knownHeight;
        const bubbleBottom = bubble.offsetTop + height;
        const visibleBottom = chat.scrollTop + chat.clientHeight - buffer;
        if (bubbleBottom > visibleBottom) {
          chat.scrollTo({ top: bubbleBottom - chat.clientHeight + buffer, behavior: 'smooth' });
        }
      }

      // The mirror of the above, for stepping backwards.
      function scrollBubbleOutOfView(chat, bubble) {
        const targetTop = Math.max(0, bubble.offsetTop - chat.clientHeight);
        if (chat.scrollTop > targetTop) {
          chat.scrollTo({ top: targetTop, behavior: 'smooth' });
        }
      }

      // Images inside a message carry no intrinsic size in this layout, so a
      // bubble revealed before its image has decoded measures short and the
      // scroll undershoots by the full height of the image. Re-run the scroll
      // once each outstanding image settles. Listeners are one-shot, so a
      // bubble revisited later costs nothing.
      function rescrollOnImageLoad(chat, bubble) {
        bubble.querySelectorAll('img').forEach(img => {
          if (img.complete) return;
          const again = () => scrollBubbleIntoView(chat, bubble);
          img.addEventListener('load', again, { once: true });
          img.addEventListener('error', again, { once: true });
        });
      }

      document.querySelectorAll('.chat').forEach(normalizeChat);

      deck.on('ready', () => {
        let hasTypingBubbles = false;

        document.querySelectorAll('.chat').forEach(chat => {
          chat.addEventListener('scroll', () => {
            chat.classList.toggle('is-scrolled', chat.scrollTop > 0);
          });

          // Link each .reaction to the bubble that precedes it.
          // Reactions may be direct children (.div syntax) or wrapped in a <p> (.span syntax).
          let bubbleCounter = 0;
          const children = Array.from(chat.children);

          // Assign IDs to all direct-child bubbles first
          children.forEach(el => {
            if (isBubble(el)) el.dataset.bubbleId = `cb-${bubbleCounter++}`;
          });

          // Find all reactions anywhere inside the chat, link to preceding bubble
          chat.querySelectorAll('.reaction').forEach(reaction => {
            // Walk up to find the direct child of chat (the flow-level container)
            let flowEl = reaction;
            while (flowEl.parentElement !== chat) flowEl = flowEl.parentElement;

            // Hide the flow-level container (reaction div or its <p> wrapper)
            flowEl.style.cssText = 'height:0;overflow:hidden;margin:0!important;padding:0!important;';

            // Find the nearest preceding sibling of flowEl that is a bubble
            let preceding = flowEl.previousElementSibling;
            while (preceding && !isBubble(preceding)) preceding = preceding.previousElementSibling;
            if (!preceding) return;

            reaction.dataset.targetBubble = preceding.dataset.bubbleId;
            preceding.classList.add('has-reactions');
          });

          // Process typing bubbles: insert an invisible reveal-trigger fragment after each
          const slide = chat.closest('section');
          if (!slide) return;

          const typingBubbles = Array.from(chat.querySelectorAll('.typing.fragment'))
            .sort((a, b) => parseInt(a.dataset.fragmentIndex) - parseInt(b.dataset.fragmentIndex));

          typingBubbles.forEach(bubble => {
            const currentIdx = parseInt(bubble.dataset.fragmentIndex);
            if (isNaN(currentIdx)) return;
            hasTypingBubbles = true;

            // Shift all other fragments in the slide with index > currentIdx
            slide.querySelectorAll('.fragment[data-fragment-index]').forEach(frag => {
              if (frag === bubble) return;
              const idx = parseInt(frag.dataset.fragmentIndex);
              if (idx > currentIdx) frag.dataset.fragmentIndex = idx + 1;
            });

            // .bubble-text already wraps the content from scaffold(), so the
            // indicator is inserted alongside it rather than rebuilding innerHTML
            // (which would destroy the avatar, name, and reactions container).
            const indicator = document.createElement('span');
            indicator.className = 'typing-indicator';
            indicator.append(
              document.createElement('span'),
              document.createElement('span'),
              document.createElement('span')
            );
            bubble.querySelector('.bubble-text').insertAdjacentElement('afterend', indicator);
            bubble.classList.add('is-typing');

            // Insert an invisible fragment that acts as the "reveal text" trigger
            const revealFrag = document.createElement('div');
            revealFrag.className = 'fragment typing-reveal';
            revealFrag.dataset.fragmentIndex = currentIdx + 1;
            revealFrag.dataset.targetTypingBubble = bubble.dataset.bubbleId;
            revealFrag.style.cssText = 'height:0;overflow:hidden;margin:0!important;padding:0!important;';
            bubble.insertAdjacentElement('afterend', revealFrag);
          });
        });

        // Re-sync Reveal.js fragment state after DOM modifications
        if (hasTypingBubbles) deck.sync();
      });

      deck.on('fragmentshown', (event) => {
        const fragment = event.fragment;
        const chat = fragment.closest('.chat');
        if (!chat) return;

        if (isReaction(fragment)) {
          const bubble = chat.querySelector(`[data-bubble-id="${fragment.dataset.targetBubble}"]`);
          if (!bubble) return;
          const pill = document.createElement('span');
          pill.className = 'reaction-pill';
          pill.textContent = fragment.textContent.trim();
          fragment._reactionPill = pill;
          bubble.querySelector('.bubble-reactions').appendChild(pill);
          // `has-reactions` is set during setup, so the room for one row of pills
          // is already reserved and the usual case costs no height. Pills that
          // wrap onto a second row do grow the message, so re-assert the anchor.
          scrollBubbleIntoView(chat, bubble);
          return;
        }

        if (isTypingReveal(fragment)) {
          const bubble = chat.querySelector(`[data-bubble-id="${fragment.dataset.targetTypingBubble}"]`);
          if (!bubble) return;
          // Scroll twice: once optimistically with the known end height so the
          // motion runs alongside the expansion, and once after it settles.
          // The first scroll is clamped by a scrollHeight that does not yet
          // include the growth, so on tall reveals it lands short on its own.
          const endHeight = animateBubble(bubble, true, () => {
            scrollBubbleIntoView(chat, bubble);
            rescrollOnImageLoad(chat, bubble);
          });
          scrollBubbleIntoView(chat, bubble, endHeight);
          return;
        }

        if (!isBubble(fragment)) return;
        scrollBubbleIntoView(chat, fragment);
        rescrollOnImageLoad(chat, fragment);
      });

      deck.on('fragmenthidden', (event) => {
        const fragment = event.fragment;
        const chat = fragment.closest('.chat');
        if (!chat) return;

        if (isReaction(fragment)) {
          if (fragment._reactionPill) {
            const pill = fragment._reactionPill;
            fragment._reactionPill = null;
            pill.classList.add('is-hiding');
            pill.addEventListener('animationend', () => pill.remove(), { once: true });
          }
          return;
        }

        if (isTypingReveal(fragment)) {
          const bubble = chat.querySelector(`[data-bubble-id="${fragment.dataset.targetTypingBubble}"]`);
          if (!bubble) return;
          // Collapsing back to dots shrinks the transcript; re-assert the anchor
          // afterwards so the dots sit where the text did rather than wherever
          // the browser's own scrollTop clamping leaves them.
          animateBubble(bubble, false, () => scrollBubbleIntoView(chat, bubble));
          return;
        }

        if (!isBubble(fragment)) return;
        scrollBubbleOutOfView(chat, fragment);
      });

    }
  };
};
