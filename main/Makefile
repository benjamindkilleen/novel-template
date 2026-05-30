INPUT=main.tex
TITLE=TITLE
DATE=$(shell date +%Y-%m-%d)
AUTHOR=Benjamin Killeen

pdf:
	pdflatex main.tex
	pdflatex main.tex # Run twice to ensure all references are updated
	mv main.pdf "${TITLE} by ${AUTHOR}.pdf"

mobile:
	pdflatex -jobname=mobile main.tex
	pdflatex -jobname=mobile main.tex # Run twice to ensure all references are updated
	mv mobile.pdf "${TITLE} by ${AUTHOR} (mobile) ${DATE}.pdf"

word:
	pandoc -o "${TITLE} by ${AUTHOR}.docx" word-main.tex \
		--reference-doc=styles/custom-reference-short.docx \
		--lua-filter=styles/manuscript.lua
	open "${TITLE} by ${AUTHOR}.docx"

rtf:
	latex2rtf simple-main.tex
	mv main.rtf "${TITLE}.rtf"

epub:
	pandoc -o "${TITLE} ${DATE}.epub" epub.tex --css=epub.css \
		--metadata author="${AUTHOR}" --metadata title="${TITLE} ${DATE}"

clean:
	rm -rf _region_.* auto *.aux *.docx *.log *.out *.pdf *.toc *.rtf *.pages *.epub *.html *.synctex.gz *.fls *.fdb_latexmk
