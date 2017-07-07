# Tex Makefile

A general purpose makefile for LaTeX projects.

## Synopsis
This makefile will compile latex projects. It updates environment variables allowing the LaTeX compiler to find files in other directories than the current one, in turn allowing the user to enjoy an orderly and neat working directory without clutter by placing files in well-arranged directories. The days of working on one huge TeX file are over. By partitioning the document into smaller pieces, and using the `\input{}` command to include them, provides a better overview and allows simultanious development on multiple parts of your document. Additionally, this setup allows you to place packages locally.

## Setup
The Makefile must be in the same directory as the main TeX file (containing the documentclass definition). You can specifically provide the name of this document by updating the `TEXFILE` variable in the makefile. Otherwise the makefile will attempt to find it.

    Project
    |-- Makefile
    |-- <TEX file>
    |-- [BIB file]
    |-- packages
        |-- *.sty
    |-- build
        |-- *.{bbl,aux,log,spl,blg}
    |-- sections
        |-- *.tex


## Usage
    > make [option] [LATEX_INCLUDE_PATH=PATH1[:PATH2[:..]]]

| Option | Description |
| --- |--- |
| pdf\*         | create pdf from <TEX file>      |
| all           | create pdf and bibtex citations |
| ls            | list local file dependencies    |
| bib           | create bib file                 |
| cite          | bibtex citations                |
| clean         | remove latex build files        |
| update        | update local texhash            |
| archive       | create tarball of local files   |
| view [viewer] | open pdf with [viewer]          |

\* = default

