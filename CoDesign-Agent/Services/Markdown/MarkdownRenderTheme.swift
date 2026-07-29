import Foundation

enum MarkdownRenderTheme {
    nonisolated static let shell = #"""
    <!doctype html>
    <html lang="zh-CN">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
      <meta http-equiv="Content-Security-Policy"
            content="default-src 'none'; img-src 'none'; media-src 'none'; connect-src 'none'; frame-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'">
      <style>
        :root {
          color-scheme: light dark;
          --text: rgba(24, 25, 31, 0.98);
          --secondary: rgba(74, 76, 91, 0.84);
          --accent: #596fe7;
          --accent-soft: rgba(89, 111, 231, 0.10);
          --border: rgba(93, 98, 126, 0.18);
          --quote-border: rgba(89, 111, 231, 0.52);
          --quote-bg: rgba(89, 111, 231, 0.07);
          --code-bg: rgba(83, 87, 109, 0.09);
          --table-stripe: rgba(83, 87, 109, 0.045);
          --font-size: 17px;
          --line-height: 1.68;
        }

        @media (prefers-color-scheme: dark) {
          :root {
            --text: rgba(245, 245, 248, 0.96);
            --secondary: rgba(218, 219, 229, 0.82);
            --accent: #95a5ff;
            --accent-soft: rgba(127, 145, 255, 0.15);
            --border: rgba(224, 226, 240, 0.19);
            --quote-border: rgba(149, 165, 255, 0.62);
            --quote-bg: rgba(127, 145, 255, 0.11);
            --code-bg: rgba(235, 236, 245, 0.10);
            --table-stripe: rgba(235, 236, 245, 0.055);
          }
        }

        html, body {
          width: 100%;
          min-height: 1px;
          margin: 0;
          padding: 0;
          overflow: hidden;
          background: transparent;
        }

        body {
          color: var(--text);
          font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "PingFang SC", sans-serif;
          font-size: var(--font-size);
          font-weight: 400;
          line-height: var(--line-height);
          letter-spacing: 0.005em;
          overflow-wrap: anywhere;
          text-rendering: optimizeLegibility;
          -webkit-font-smoothing: antialiased;
        }

        #markdown-root {
          width: 100%;
          box-sizing: border-box;
        }

        #stable-content, #draft-content {
          width: 100%;
          box-sizing: border-box;
        }

        #draft-content[data-mode="plain"] {
          white-space: pre-wrap;
        }

        #draft-content.streaming::after {
          content: "";
          display: inline-block;
          width: 0.42em;
          height: 1.05em;
          margin-left: 0.14em;
          border-radius: 0.2em;
          vertical-align: -0.14em;
          background: var(--accent);
          opacity: 0.58;
          animation: caretPulse 1s ease-in-out infinite;
        }

        @keyframes caretPulse {
          0%, 100% { opacity: 0.22; }
          50% { opacity: 0.82; }
        }

        @media (prefers-reduced-motion: reduce) {
          #draft-content.streaming::after { animation: none; opacity: 0.5; }
        }

        p {
          margin: 0 0 0.82em;
        }

        p:last-child,
        ul:last-child,
        ol:last-child,
        blockquote:last-child,
        pre:last-child,
        .table-scroll:last-child {
          margin-bottom: 0;
        }

        h1, h2, h3, h4, h5, h6 {
          margin: 1.05em 0 0.42em;
          color: var(--text);
          font-weight: 700;
          line-height: 1.28;
        }

        h1:first-child, h2:first-child, h3:first-child,
        h4:first-child, h5:first-child, h6:first-child {
          margin-top: 0;
        }

        h1 { font-size: 1.48em; }
        h2 { font-size: 1.30em; }
        h3 { font-size: 1.16em; }
        h4, h5, h6 { font-size: 1.04em; }

        strong { font-weight: 700; }
        em { font-style: italic; }
        del { color: var(--secondary); }

        a {
          color: var(--accent);
          text-decoration: underline;
          text-decoration-thickness: 0.08em;
          text-underline-offset: 0.16em;
        }

        ul, ol {
          margin: 0.2em 0 0.9em;
          padding-left: 1.5em;
        }

        li {
          margin: 0.26em 0;
          padding-left: 0.12em;
        }

        li > p {
          margin: 0;
        }

        .task-marker {
          color: var(--accent);
          font-variant-numeric: tabular-nums;
        }

        blockquote {
          margin: 0.45em 0 0.95em;
          padding: 0.66em 0.86em;
          border-left: 3px solid var(--quote-border);
          border-radius: 0 10px 10px 0;
          background: var(--quote-bg);
          color: var(--secondary);
        }

        code {
          padding: 0.10em 0.34em;
          border-radius: 0.34em;
          background: var(--code-bg);
          font-family: ui-monospace, "SFMono-Regular", Menlo, monospace;
          font-size: 0.88em;
        }

        pre {
          box-sizing: border-box;
          max-width: 100%;
          margin: 0.45em 0 0.95em;
          padding: 0.85em 0.95em;
          overflow-x: auto;
          border: 1px solid var(--border);
          border-radius: 10px;
          background: var(--code-bg);
          white-space: pre;
          -webkit-overflow-scrolling: touch;
        }

        pre code {
          padding: 0;
          border-radius: 0;
          background: transparent;
          font-size: 0.84em;
          line-height: 1.55;
        }

        .table-scroll {
          max-width: 100%;
          margin: 0.45em 0 0.95em;
          overflow-x: auto;
          border: 1px solid var(--border);
          border-radius: 10px;
          -webkit-overflow-scrolling: touch;
        }

        table {
          width: 100%;
          min-width: max-content;
          border-collapse: collapse;
          font-size: 0.92em;
        }

        th, td {
          padding: 0.54em 0.72em;
          border-right: 1px solid var(--border);
          border-bottom: 1px solid var(--border);
          text-align: left;
          vertical-align: top;
        }

        th {
          background: var(--accent-soft);
          font-weight: 650;
        }

        tr:nth-child(even) td { background: var(--table-stripe); }
        tr:last-child td { border-bottom: 0; }
        th:last-child, td:last-child { border-right: 0; }
        .align-center { text-align: center; }
        .align-right { text-align: right; }

        hr {
          height: 1px;
          margin: 1em 0;
          border: 0;
          background: var(--border);
        }

        .raw-markdown-html,
        .image-alt {
          color: var(--secondary);
        }
      </style>
    </head>
    <body>
      <main id="markdown-root" class="ai-answer" aria-live="polite" aria-busy="false">
        <section id="stable-content"></section>
        <section id="draft-content"></section>
      </main>
      <script>
        (() => {
          const content = document.getElementById("markdown-root");
          const stable = document.getElementById("stable-content");
          const draft = document.getElementById("draft-content");
          let lastHeight = -1;

          const reportHeight = () => {
            const height = Math.ceil(Math.max(
              content.getBoundingClientRect().height,
              document.documentElement.scrollHeight,
              document.body.scrollHeight
            ));
            if (height !== lastHeight) {
              lastHeight = height;
              window.webkit.messageHandlers.contentHeight.postMessage(height);
            }
          };

          const renderer = {
            reset() {
              stable.replaceChildren();
              draft.replaceChildren();
              draft.removeAttribute("data-mode");
              reportHeight();
            },
            replaceStableContent(html) {
              stable.innerHTML = html || "";
              reportHeight();
            },
            appendStableBlock(id, html) {
              if (document.getElementById(id)) return;
              const block = document.createElement("div");
              block.id = id;
              block.innerHTML = html || "";
              stable.appendChild(block);
              reportHeight();
            },
            updateDraft(html) {
              draft.dataset.mode = "html";
              draft.innerHTML = html || "";
              reportHeight();
            },
            updateDraftPlainText(text) {
              draft.dataset.mode = "plain";
              draft.textContent = text || "";
              reportHeight();
            },
            finalize(html) {
              stable.innerHTML = html || "";
              draft.replaceChildren();
              draft.removeAttribute("data-mode");
              renderer.setStreaming(false);
              reportHeight();
            },
            setStreaming(value) {
              const active = Boolean(value);
              draft.classList.toggle("streaming", active);
              content.setAttribute("aria-busy", active ? "true" : "false");
              reportHeight();
            },
            setFontSize(points) {
              const value = Number(points);
              if (Number.isFinite(value) && value >= 12 && value <= 36) {
                document.documentElement.style.setProperty("--font-size", `${value}px`);
                reportHeight();
              }
            },
            setTheme(theme) {
              document.documentElement.dataset.theme = theme || "system";
              reportHeight();
            },
            scrollToBottomIfNeeded() {
              // The outer SwiftUI ScrollView owns scrolling. Intentionally do not
              // steal reading position from a user who has moved away from the end.
              return false;
            }
          };

          window.codesignRenderer = renderer;
          const observer = new ResizeObserver(reportHeight);
          observer.observe(content);
          window.addEventListener("load", () => {
            window.webkit.messageHandlers.rendererReady.postMessage(true);
            reportHeight();
          });
        })();
      </script>
    </body>
    </html>
    """#
}
