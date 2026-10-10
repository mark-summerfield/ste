# Copyright © 2025-26 Mark Summerfield. All rights reserved.

package require html 1
package require ntext 1
package require scrollutil_tile 2
package require ui

oo::class create TextEdit {
    variable Frame
    variable Text
    variable Completion
    variable CompletionMenu
    variable ContextMenu
}

package require textedit_actions
package require textedit_export
package require textedit_export_html
package require textedit_export_odt
package require textedit_export_xml
package require textedit_import
package require textedit_import_html
package require textedit_import_xml
package require textedit_initialize
package require textedit_serialize

oo::define TextEdit classmethod make_color_menu {the_menu the_callback} {
    ;#             K E N B L C T V G I A W D O R P U M
    const INDEXES {4 2 0 0 0 0 0 3 0 1 1 3 3 0 0 0 1 0}
    foreach index $INDEXES {name color} [TextEdit colors] {
        $the_menu add command -underline $index \
            -image [my swatch $color $::MENU_ICON_SIZE] \
            -compound left -label [string totitle $name] \
            -command "$the_callback $name"
    }
}

oo::define TextEdit classmethod swatch {color size} {
    const R [expr {max(3, $size / 4.0)}]
    const W [expr {$R + 2.5}]
    image create photo -data "<svg width=\"$size\" height=\"$size\">
        <rect x=\"0\" y=\"0\" width=\"$size\" height=\"$size\" rx=\"$R\"
        ry=\"$R\" fill=\"$color\" stroke-width=\"$W\" stroke=\"white\">
        </svg>"
}

oo::define TextEdit constructor {parent {sans ""} {serif ""} {mono ""} \
        {size 0}} {
    my ensure_fonts $sans $serif $mono $size
    classvariable N
    if {![string match *. $parent]} { set parent $parent. }
    set Frame ${parent}tf#[incr N] ;# unique
    ttk::frame $Frame
    set sa [scrollutil::scrollarea $Frame.sa -xscrollbarmode none]
    set tab [expr {4 * [font measure Roman n]}]
    set Text [text $Frame.sa.txt -undo 1 -wrap word -font Roman \
            -tabstyle wordprocessor -tabs "$tab left"]
    my make_tags
    $sa setwidget $Text
    pack $sa -fill both -expand 1
    set Completion 1
    set CompletionMenu [menu $Frame.completionMenu]
    my MakeContextMenu
    my MakeBindings
}

oo::define TextEdit method completion {} { return $Completion }

oo::define TextEdit method set_completion value { set Completion $value }

oo::define TextEdit method MakeContextMenu {} {
    set ContextMenu [menu $Frame.contextMenu]
    $ContextMenu add command -command [callback apply_style highlight] \
        -label Highlight -underline 0 -compound left \
        -image [ui::icon draw-highlight.svg $::MENU_ICON_SIZE]
    $ContextMenu add separator
    menu $ContextMenu.fonts
    $ContextMenu add cascade -menu $ContextMenu.fonts -label Font \
            -underline 0 -compound left \
            -image [ui::icon preferences-desktop-font.svg $::MENU_ICON_SIZE]
    my make_font_menu $ContextMenu.fonts [callback apply_font]
    $ContextMenu add separator
    my make_color_menu $ContextMenu [callback apply_color]
}

oo::define TextEdit method MakeBindings {} {
    set ::ntext::tabColor ""
    bindtags $Text [list $Text Ntext [winfo toplevel $Text] all]
    bind $Text <<ContextMenu>> "tk_popup $ContextMenu %X %Y"
    bind $Text <Control-Prior> [callback on_ctrl_prior]
    bind $Text <Control-Next> [callback on_ctrl_next]
    bind $Text <Control-Delete> [callback on_ctrl_del]
    bind $Text <BackSpace> [callback on_bs]
    bind $Text <Control-BackSpace> [callback on_ctrl_bs]
    bind $Text <Control-a> [callback on_ctrl_a]
    bind $Text <Double-1> [callback on_double_click]
    bind $Text <'> [callback on_single_quote]
    bind $Text <Tab> [callback on_tab]
    bind $Text <Control-Tab> [callback on_ctrl_tab]
    bind $Text <Control-Key-1> [callback on_ctrl_key_1]
    bind $Text <Return> [callback on_return]
}

oo::define TextEdit classmethod make_font_menu {the_menu the_callback} {
    variable FONT_KINDS
    foreach kind $FONT_KINDS index {0 1 0} {
        $the_menu add command -underline $index \
                -label [string totitle $kind] -command "$the_callback $kind"
    }
}

# Only creates the fonts the first time
oo::define TextEdit classmethod ensure_fonts {sans serif mono size} {
    variable Initialized
    if {$Initialized} return
    set Initialized 1
    my make_fonts $sans $serif $mono $size
}

# Creates (or reconfigures, so any widgets using them update) the three
# families of named fonts: Roman, Small, Bold, Italic, BoldItalic, H1-H4
# (sans), and SerifRoman, ..., MonoRoman, ...
oo::define TextEdit classmethod make_fonts {sans serif mono size} {
    variable DEFAULT_FAMILIES
    variable FONT_KINDS
    variable FONT_SPECS
    variable FamilyFor
    variable Size
    foreach kind $FONT_KINDS {
        if {[set $kind] eq ""} {
            set $kind [dict get $DEFAULT_FAMILIES $kind]
        }
    }
    if {!$size} {
        set size [expr {1 + [font configure TkDefaultFont -size]}]
    }
    set FamilyFor [dict create sans $sans serif $serif mono $mono]
    set Size $size
    foreach kind $FONT_KINDS {
        set family [dict get $FamilyFor $kind]
        foreach {suffix scale weight slant} $FONT_SPECS {
            set name [my font_name $kind $suffix]
            set opts [list -family $family -weight $weight -slant $slant \
                    -size [expr {int(round($size * $scale))}]]
            if {$name in [font names]} {
                font configure $name {*}$opts
            } else {
                font create $name {*}$opts
            }
        }
    }
}

oo::define TextEdit classmethod font_name {kind suffix} {
    switch $kind {
        serif { return Serif$suffix }
        mono { return Mono$suffix }
        default { return $suffix }
    }
}

oo::define TextEdit classmethod font_size {} {
    variable Size
    return $Size
}

oo::define TextEdit classmethod family_for kind {
    variable FamilyFor
    dict get $FamilyFor $kind
}

# Tag names starting with this are internal (see refresh_fonts).
oo::define TextEdit classmethod derived_tag {kind style} {
    return fnt:$kind:$style
}

# Use after the user changes the font families or size.
oo::define TextEdit method set_fonts {sans serif mono size} {
    my make_fonts $sans $serif $mono $size
    my ConfigureIndents
    my refresh_fonts [list 1.0 end]
}

oo::define TextEdit method make_tags {} {
    classvariable URL_UL_COLOR
    classvariable HIGHLIGHT_COLOR
    classvariable COLOR_FOR_TAG
    classvariable FONT_STYLES
    classvariable FONT_FOR_STYLE
    # The font tags must be the lowest priority; see refresh_fonts.
    $Text tag configure serif -font SerifRoman
    $Text tag configure mono -font MonoRoman
    $Text tag configure sub -font Small -offset -3p
    $Text tag configure sup -font Small -offset 3p
    $Text tag configure ul -underline 1
    $Text tag configure strike -overstrike 1 -overstrikefg #FF1A1A
    $Text tag configure center -justify center
    $Text tag configure right -justify right
    $Text tag configure url -underline 1 -underlinefg $URL_UL_COLOR
    $Text tag configure h1 -font H1
    $Text tag configure h2 -font H2
    $Text tag configure h3 -font H3
    $Text tag configure h4 -font H4
    $Text tag configure bold -font Bold
    $Text tag configure italic -font Italic
    $Text tag configure bolditalic -font BoldItalic
    $Text tag configure highlight -background $HIGHLIGHT_COLOR
    my ConfigureIndents
    dict for {key value} $COLOR_FOR_TAG {
        $Text tag configure $key -foreground $value
    }
    # One tag per family+style combination, e.g. fnt:serif:bold; Tk tags
    # can't combine fonts so refresh_fonts applies these (highest
    # priority) wherever a serif or mono run also has a font style.
    foreach kind {serif mono} {
        foreach style $FONT_STYLES {
            $Text tag configure [my derived_tag $kind $style] \
                -font [my font_name $kind [dict get $FONT_FOR_STYLE $style]]
        }
    }
}

oo::define TextEdit method ConfigureIndents {} {
    $Text configure -tabs "[expr {4 * [font measure Roman n]}] left"
    set BINDENT [font measure Roman " • "]
    set NINDENT [font measure Roman "9. "]
    set TINDENT [font measure Roman "   "]
    $Text tag configure bindent0 -lmargin1 0 -lmargin2 $BINDENT
    $Text tag configure bindent1 -lmargin1 $BINDENT \
        -lmargin2 [expr {2 * $BINDENT}]
    $Text tag configure bindent2 -lmargin1 [expr {2 * $BINDENT}] \
        -lmargin2 [expr {3 * $BINDENT}]
    $Text tag configure tindent0 -lmargin1 0 -lmargin2 $TINDENT
    $Text tag configure tindent1 -lmargin1 $TINDENT \
        -lmargin2 [expr {2 * $TINDENT}]
    $Text tag configure tindent2 -lmargin1 [expr {2 * $TINDENT}] \
        -lmargin2 [expr {3 * $TINDENT}]
    $Text tag configure nindent0 -lmargin1 0 -lmargin2 $NINDENT
    $Text tag configure nindent1 -lmargin1 $NINDENT \
        -lmargin2 [expr {2 * $NINDENT}]
    $Text tag configure nindent2 -lmargin1 [expr {2 * $NINDENT}] \
        -lmargin2 [expr {3 * $NINDENT}]
}

oo::define TextEdit classmethod filetypes {} {
    variable FILETYPES
    return $FILETYPES
}

oo::define TextEdit classmethod colors {} {
    variable COLOR_FOR_TAG
    return $COLOR_FOR_TAG
}

oo::define TextEdit method unknown {the_method args} {
    $Text $the_method {*}$args
}

oo::define TextEdit method focus {} { focus $Text }

oo::define TextEdit method ttk_frame {} { return $Frame }

oo::define TextEdit method tk_text {} { return $Text }

oo::define TextEdit method isempty {} {
    expr {[string trim [$Text get 1.0 end]] eq ""}
}

oo::define TextEdit method clear {} {
    $Text delete 1.0 end
    $Text edit reset
    $Text edit modified 0
}

oo::define TextEdit method after_load {{index insert}} {
    my highlight_urls
    my refresh_fonts [list 1.0 end]
    $Text edit reset
    $Text edit modified 0
    if {$index ne "insert"} { $Text mark set insert $index }
    $Text see $index
}

oo::define TextEdit method first_line {} { string trim [$Text get 1.0 2.0] }

oo::define TextEdit method highlight_urls {} {
    foreach i [$Text search -all -regexp {(?:https?://|~/)} 1.0] {
        set j [$Text search -regexp {[\s>]} $i]
        if {[$Text get "$j -1 char"] eq "."} {
            set j [$Text index "$j -1 char"]
        }
        $Text tag add url $i $j
    }
}

oo::define TextEdit method selected {} {
    if {[set indexes [$Text tag ranges sel]] ne ""} {
        return $indexes
    }
    return "[$Text index "insert wordstart"] [$Text index "insert wordend"]"
}

oo::define TextEdit method get_whole_word {} {
    set a [$Text index "insert linestart"]
    set b [$Text index "insert lineend"]
    set c [$Text index "insert wordstart"]
    set i [$Text search -backwards -exact " " $c "$a -1 char"]
    if {$i eq ""} { set i $a }
    set j [$Text search -exact " " insert "$b +1 char"]
    if {$j eq ""} { set j [$Text index $b] }
    string trim [string trimright [$Text get $i $j] ",;:!?."]
}

oo::define TextEdit method apply_style style {
    my apply_style_to [my selected] $style
}

oo::define TextEdit method apply_style_to {indexes style} {
    if {$indexes ne ""} {
        set tags [$Text tag names [lindex $indexes 0]]
        if {$style eq "bold" && "bolditalic" in $tags} {
            $Text tag remove bolditalic {*}$indexes
            $Text tag add italic {*}$indexes
        } elseif {$style eq "italic" && "bolditalic" in $tags} {
            $Text tag remove bolditalic {*}$indexes
            $Text tag add bold {*}$indexes
        } elseif {($style eq "bold" && "italic" in $tags) ||
                  ($style eq "italic" && "bold" in $tags)} {
            $Text tag remove bold {*}$indexes
            $Text tag remove italic {*}$indexes
            $Text tag add bolditalic {*}$indexes
        } elseif {$style eq "bold" && "bold" in $tags} {
            $Text tag remove bold {*}$indexes
        } elseif {$style eq "italic" && "italic" in $tags} {
            $Text tag remove italic {*}$indexes
        } elseif {$style eq "highlight" && "highlight" in $tags} {
            $Text tag remove highlight {*}$indexes
        } elseif {$style eq "sub" && "sub" in $tags} {
            $Text tag remove sub {*}$indexes
        } elseif {$style eq "sup" && "sup" in $tags} {
            $Text tag remove sup {*}$indexes
        } elseif {$style eq "ul" && "ul" in $tags} {
            $Text tag remove ul {*}$indexes
        } elseif {$style eq "strike" && "strike" in $tags} {
            $Text tag remove strike {*}$indexes
        } elseif {$style eq "h1" && "h1" in $tags} {
            $Text tag remove h1 {*}$indexes
        } elseif {$style eq "h2" && "h2" in $tags} {
            $Text tag remove h2 {*}$indexes
        } elseif {$style eq "h3" && "h3" in $tags} {
            $Text tag remove h3 {*}$indexes
        } elseif {$style eq "h4" && "h4" in $tags} {
            $Text tag remove h4 {*}$indexes
        } else {
            if {$style in {h1 h2 h3 h4}} {
                foreach tag {h1 h2 h3 h4 sub sup ul strike bold italic \
                        bolditalic} {
                    $Text tag remove $tag {*}$indexes
                }
            }
            $Text tag add $style {*}$indexes
        }
        my refresh_fonts $indexes
        $Text edit modified 1
    }
}

oo::define TextEdit method apply_font kind {
    my apply_font_to [my selected] $kind
}

# kind is sans (the default, no tag), serif, or mono
oo::define TextEdit method apply_font_to {indexes kind} {
    if {$indexes ne ""} {
        $Text tag remove serif {*}$indexes
        $Text tag remove mono {*}$indexes
        if {$kind ne "sans"} { $Text tag add $kind {*}$indexes }
        my refresh_fonts $indexes
        $Text edit modified 1
    }
}

# Tk tags cannot combine fonts: a bold tag's font replaces a serif
# tag's. So for every span of text that is serif or mono and also has a
# font-changing style (bold, h1, sub, etc.), add the derived tag
# fnt:<kind>:<style> whose font has both. The derived tags are internal:
# they are never saved or exported (see StripDerived and
# XmlClassifyTag), so this must be called whenever the text's family or
# styles change, or after loading.
# `indexes` is a list of {from to ...} pairs.
oo::define TextEdit method refresh_fonts indexes {
    classvariable FONT_STYLES
    foreach {from to} $indexes {
        set from [$Text index $from]
        set to [$Text index $to]
        if {[$Text compare $from >= $to]} continue
        foreach kind {serif mono} {
            foreach style $FONT_STYLES {
                $Text tag remove [my derived_tag $kind $style] $from $to
            }
        }
        set points [list $from $to]
        foreach tag [concat {serif mono} $FONT_STYLES] {
            foreach {a b} [$Text tag ranges $tag] {
                foreach p [list $a $b] {
                    if {[$Text compare $p > $from] &&
                            [$Text compare $p < $to]} {
                        lappend points $p
                    }
                }
            }
        }
        set points [lsort -unique -command [callback CompareIndexes] \
                $points]
        foreach a [lrange $points 0 end-1] b [lrange $points 1 end] {
            set tags [$Text tag names $a]
            set kind [expr {"mono" in $tags ? "mono" : "serif" in $tags \
                    ? "serif" : ""}]
            if {$kind eq ""} continue
            set winner ""
            foreach style $FONT_STYLES {
                if {$style in $tags} { set winner $style }
            }
            if {$winner ne ""} {
                $Text tag add [my derived_tag $kind $winner] $a $b
            }
        }
    }
}

oo::define TextEdit method CompareIndexes {a b} {
    if {[$Text compare $a < $b]} { return -1 }
    if {[$Text compare $a > $b]} { return 1 }
    return 0
}

oo::define TextEdit method apply_align align {
    set i [$Text index "insert linestart"]
    set j [$Text index "insert lineend"]
    my apply_align_to [list $i $j] $align
}

oo::define TextEdit method apply_align_to {indexes align} {
    if {$indexes ne ""} {
        if {$align eq "left"} {
            $Text tag remove center {*}$indexes
            $Text tag remove right {*}$indexes
        } else {
            set tags [$Text tag names [lindex $indexes 0]]
            if {$align eq "center" && "center" in $tags} {
                $Text tag remove center {*}$indexes
            } elseif {$align eq "right" && "right" in $tags} {
                $Text tag remove right {*}$indexes
            } else {
                if {$align eq "center" && "right" in $tags} {
                    $Text tag remove right {*}$indexes
                } elseif {$align eq "right" && "center" in $tags} {
                    $Text tag remove center {*}$indexes
                }
                $Text tag add $align {*}$indexes
            }
        }
        $Text edit modified 1
    }
}

oo::define TextEdit method apply_color color {
    my apply_color_to [my selected] $color
}

oo::define TextEdit method apply_color_to {indexes color} {
    classvariable COLOR_FOR_TAG
    foreach tag [dict keys $COLOR_FOR_TAG] {
        $Text tag remove $tag {*}$indexes
    }
    if {$color ne "black"} {
        $Text tag add $color {*}$indexes
    }
    $Text edit modified 1
}

oo::define TextEdit method show_indents show {
    if {$show} {
        $Text tag configure bindent0 -background #FFB4B4
        $Text tag configure bindent1 -background #FFCDCD
        $Text tag configure bindent2 -background #FFE7E7
        $Text tag configure tindent0 -background #B4FFB4
        $Text tag configure tindent1 -background #CDFFCD
        $Text tag configure tindent2 -background #E7FFE7
        $Text tag configure nindent0 -background #B4B4FF
        $Text tag configure nindent1 -background #CDCDFF
        $Text tag configure nindent2 -background #E7E7FF
    } else {
        foreach n {0 1 2} {
            $Text tag configure bindent$n -background {}
            $Text tag configure nindent$n -background {}
            $Text tag configure tindent$n -background {}
        }
    }
}
