-- Pandoc Lua filter: build a modern (Shunn) manuscript first page for the
-- docx output, and compute the word count automatically.
--
-- It reads the metadata that the LaTeX source already provides:
--   \title{...}   -> the book title (centered, ~1/3 down page 1)
--   \author{...}  -> the byline ("by <author>")
--   \date{...}    -> the contact block (name / address / phone / email),
--                    placed top-left; word count goes top-right.
--
-- The default pandoc title block is suppressed; we emit our own raw OOXML so
-- we get exact manuscript layout (right-aligned tab stop, single-spaced
-- contact block, half-page drop before the title).

local utils = pandoc.utils

-- Right margin position in twips for a US Letter page with 1" margins:
-- 12240 - 1440 (left) - 1440 (right) = 9360.
local RIGHT_TAB = 9360

local function xml_escape(s)
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

-- Group a list of inlines into lines split on LineBreak / SoftBreak.
local function inlines_to_lines(inlines)
  local lines, cur = {}, {}
  for _, el in ipairs(inlines or {}) do
    if el.t == "LineBreak" or el.t == "SoftBreak" then
      table.insert(lines, utils.stringify(cur))
      cur = {}
    else
      table.insert(cur, el)
    end
  end
  table.insert(lines, utils.stringify(cur))
  return lines
end

local function format_count(n)
  -- Round: nearest 100 below 10k, nearest 1000 at/above.
  local rounded
  if n < 10000 then
    rounded = math.floor((n + 50) / 100) * 100
  else
    rounded = math.floor((n + 500) / 1000) * 1000
  end
  -- Insert thousands separators.
  local s = tostring(rounded)
  local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
  out = out:gsub("^,", "")
  return out
end

-- Count words across the whole document body.
local function count_words(blocks)
  local text = utils.stringify(pandoc.Pandoc(blocks))
  local n = 0
  for _ in text:gmatch("%S+") do n = n + 1 end
  return n
end

local function p_open(extra)
  return '<w:p><w:pPr>' .. (extra or '')
end

-- Build the manuscript first page as raw OOXML blocks.
local function build_title_page(title, author, contact_lines, wordcount)
  -- Contact block: single-spaced, left aligned. First line carries a
  -- right-aligned tab stop with the word count.
  local parts = {}
  table.insert(parts,
    '<w:p><w:pPr>' ..
    '<w:spacing w:after="0" w:line="240" w:lineRule="auto"/>' ..
    '<w:ind w:firstLine="0"/>' ..
    '<w:tabs><w:tab w:val="right" w:pos="' .. RIGHT_TAB .. '"/></w:tabs>' ..
    '</w:pPr>')
  for i, line in ipairs(contact_lines) do
    if i > 1 then table.insert(parts, '<w:r><w:br/></w:r>') end
    table.insert(parts, '<w:r><w:t xml:space="preserve">' .. xml_escape(line) .. '</w:t></w:r>')
    if i == 1 then
      table.insert(parts,
        '<w:r><w:tab/><w:t xml:space="preserve">' ..
        xml_escape('approximately ' .. wordcount .. ' words') ..
        '</w:t></w:r>')
    end
  end
  table.insert(parts, '</w:p>')

  -- Spacer that drops the title roughly one-third of the way down page 1.
  table.insert(parts,
    '<w:p><w:pPr><w:spacing w:before="3600" w:after="0" w:line="240" w:lineRule="auto"/></w:pPr></w:p>')

  -- Title, centered, double-spaced.
  table.insert(parts,
    '<w:p><w:pPr>' ..
    '<w:spacing w:after="0" w:line="480" w:lineRule="auto"/>' ..
    '<w:ind w:firstLine="0"/><w:jc w:val="center"/></w:pPr>' ..
    '<w:r><w:t xml:space="preserve">' .. xml_escape(title) .. '</w:t></w:r></w:p>')

  -- Byline, centered, double-spaced.
  table.insert(parts,
    '<w:p><w:pPr>' ..
    '<w:spacing w:after="0" w:line="480" w:lineRule="auto"/>' ..
    '<w:ind w:firstLine="0"/><w:jc w:val="center"/></w:pPr>' ..
    '<w:r><w:t xml:space="preserve">' .. xml_escape('by ' .. author) .. '</w:t></w:r></w:p>')

  -- Blank double-spaced line before the story begins.
  table.insert(parts,
    '<w:p><w:pPr><w:spacing w:after="0" w:line="480" w:lineRule="auto"/></w:pPr></w:p>')

  return pandoc.RawBlock("openxml", table.concat(parts, ""))
end

-- A page break followed by blank double-spaced lines, so the chapter title
-- that follows lands roughly one-third of the way down the new page (modern
-- manuscript convention). Heading1's own pageBreakBefore is removed in the
-- reference doc so this is the single source of the break.
local function chapter_break()
  local parts = { '<w:p><w:r><w:br w:type="page"/></w:r></w:p>' }
  for _ = 1, 7 do
    table.insert(parts,
      '<w:p><w:pPr><w:spacing w:after="0" w:line="480" w:lineRule="auto"/></w:pPr></w:p>')
  end
  return pandoc.RawBlock("openxml", table.concat(parts, ""))
end

function Pandoc(doc)
  local meta = doc.meta

  local title = meta.title and utils.stringify(meta.title) or "Untitled"
  local author = meta.author and utils.stringify(meta.author) or ""
  local contact_lines = meta.date and inlines_to_lines(meta.date) or {}
  -- Drop empty trailing contact lines.
  while #contact_lines > 0 and contact_lines[#contact_lines]:match("^%s*$") do
    table.remove(contact_lines)
  end
  if #contact_lines == 0 and author ~= "" then
    contact_lines = { author }
  end

  local wordcount = format_count(count_words(doc.blocks))

  -- Suppress pandoc's automatic title block.
  meta.title = nil
  meta.author = nil
  meta.date = nil

  -- Drop each chapter title ~1/3 down a fresh page. Skip a break before the
  -- very first body block (the story opens under the title block on page 1).
  local blocks = {}
  for i, b in ipairs(doc.blocks) do
    if b.t == "Header" and b.level == 1 and i > 1 then
      table.insert(blocks, chapter_break())
    end
    table.insert(blocks, b)
  end

  local page = build_title_page(title, author, contact_lines, wordcount)
  table.insert(blocks, 1, page)

  return pandoc.Pandoc(blocks, meta)
end
