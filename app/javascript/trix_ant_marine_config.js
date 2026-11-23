import Trix from "trix"

// Trix 2.1.19 block + text extensions for ANT Marine (idempotent).
if (!Trix.config.blockAttributes.heading2) {
  Trix.config.blockAttributes.heading2 = {
    tagName: "h2",
    terminal: true,
    breakOnReturn: true,
    group: false
  }
}

if (!Trix.config.blockAttributes.heading3) {
  Trix.config.blockAttributes.heading3 = {
    tagName: "h3",
    terminal: true,
    breakOnReturn: true,
    group: false
  }
}

if (!Trix.config.textAttributes.underline) {
  Trix.config.textAttributes.underline = {
    tagName: "u",
    inheritable: true,
    parser(element) {
      const tag = element.tagName?.toLowerCase()
      if (tag === "u") return true
      const style = window.getComputedStyle(element)
      return style.textDecorationLine?.includes("underline")
    }
  }
}

export const ANT_RICH_TEXT_HEADING_ATTRS = ["heading1", "heading2", "heading3"]
export const ANT_RICH_TEXT_INLINE_ATTRS = ["bold", "italic", "underline", "strike", "href"]
export const ANT_RICH_TEXT_BLOCK_ATTRS = ["quote", "code", "bullet", "number", ...ANT_RICH_TEXT_HEADING_ATTRS]