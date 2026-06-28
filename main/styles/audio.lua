-- Audio-build pandoc filter: strip content that shouldn't be narrated.
-- Applied only to the audio EPUB (see `make audio-epub`); the print/ebook
-- `epub` target is unaffected.
local utils = pandoc.utils

-- Drop \todo{...} -> pandoc renders it as an empty-attr Span beginning "[TODO:".
function Span(el)
  if utils.stringify(el):match("^%s*%[TODO:") then return {} end
end

-- Drop \scene -> \section*{\#} -> a level-2 Header whose text is just "#"
-- (otherwise narrated as "number sign").
function Header(el)
  if utils.stringify(el) == "#" then return {} end
end

-- Drop the \date{} contact block (address / phone / email) from narration.
function Meta(m)
  m.date = nil
  return m
end
