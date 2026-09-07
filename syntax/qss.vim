" ~/.config/nvim/syntax/qss.vim
if exists("b:current_syntax")
  finish
endif


" -- Comments (QSS only supports /* */, no //) --
syntax region qssComment start="/\*" end="\*/" contains=@Spell

highlight link qssComment Comment

" -- Selectors --
" Widget class names (QPushButton, QWidget, etc.) - anything starting with Q
syntax match qssWidget "\<Q[A-Za-z0-9_]*\>"

highlight link qssWidget Type

" #objectName and .property-class style selectors
syntax match qssId "#[A-Za-z0-9_-]\+"

highlight link qssId Identifier

" ::sub-control (e.g. ::drop-down, ::indicator)
syntax match qssSubControl "::[A-Za-z-]\+"

highlight link qssSubControl Special

" :pseudo-state (e.g. :hover, :pressed, :disabled)
syntax match qssPseudoState ":[A-Za-z-]\+"

highlight link qssPseudoState PreProc

" [property="value"] attribute selectors
syntax region qssAttribute start="\[" end="\]" contains=qssString,qssAttrProp
syntax match qssAttrProp "[A-Za-z_-]\+" contained containedin=qssAttribute

highlight link qssAttrProp Identifier

" Combinators
syntax match qssCombinator "[>,]"

highlight link qssCombinator Operator

" -- Braces / property blocks --
syntax region qssBlock start="{" end="}" transparent fold contains=qssProperty,qssValue,qssComment,qssString,qssColor,qssNumber,qssImportant

" property: value;
syntax match qssProperty "[A-Za-z-]\+\s*:"me=e-1 contained containedin=qssBlock

highlight link qssProperty Statement

" -- Values --
syntax match qssNumber "\<-\?\d\+\(\.\d\+\)\?\(px\|pt\|em\)\?\>" contained containedin=qssBlock
syntax match qssColor "#[0-9A-Fa-f]\{3,8\}\>" contained containedin=qssBlock
syntax match qssColor "\<rgba\?\ze(" contained containedin=qssBlock nextgroup=qssParen
syntax match qssColor "\<qlineargradient\ze(" contained containedin=qssBlock
syntax match qssColor "\<qradialgradient\ze(" contained containedin=qssBlock
syntax match qssColor "\<qconicalgradient\ze(" contained containedin=qssBlock
syntax match qssColor "\<palette\ze(" contained containedin=qssBlock
syntax match qssUrl "\<url\ze(" contained containedin=qssBlock

syntax region qssString start=+"+ skip=+\\"+ end=+"+ contained containedin=qssBlock,qssAttribute
syntax region qssString start=+'+ skip=+\\'+ end=+'+ contained containedin=qssBlock,qssAttribute

highlight link qssNumber Number
highlight link qssColor Constant
highlight link qssUrl Function
highlight link qssString String


let b:current_syntax = "qss"
