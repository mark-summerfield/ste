# Copyright © 2025-26 Mark Summerfield. All rights reserved.

package require html 1
package require ntext 1
package require scrollutil_tile 2
package require ui

oo::class create Ste {
    variable Frame
    variable Text
    variable Completion
    variable CompletionMenu
    variable ContextMenu
}

package require ste_actions
package require ste_export
package require ste_export_html
package require ste_export_odt
package require ste_export_xml
package require ste_import
package require ste_import_html
package require ste_import_xml
package require ste_initialize
package require ste_serialize

oo::define Ste classmethod make_color_menu {the_menu the_callback} {
    ;#             K E N B L C T V G I A W D O R P U M
    const INDEXES {4 2 0 0 0 0 0 3 0 1 1 3 3 0 0 0 1 0}
    foreach index $INDEXES {name color} [Ste colors] {
        $the_menu add command -underline $index \
            -image [my swatch $color $::MENU_ICON_SIZE] \
            -compound left -label [string totitle $name] \
            -command "$the_callback $name"
    }
}

oo::define Ste classmethod swatch {color size} {
    const R [expr {max(3, $size / 4.0)}]
    const W [expr {$R + 2.5}]
    image create photo -data "<svg width=\"$size\" height=\"$size\">
        <rect x=\"0\" y=\"0\" width=\"$size\" height=\"$size\" rx=\"$R\"
        ry=\"$R\" fill=\"$color\" stroke-width=\"$W\" stroke=\"white\">
        </svg>"
}

oo::define Ste constructor {parent {fonts {}}} {
    my ensure_fonts $fonts
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

oo::define Ste method completion {} { return $Completion }

oo::define Ste method set_completion value { set Completion $value }

oo::define Ste method MakeContextMenu {} {
    set ContextMenu [menu $Frame.contextMenu]
    $ContextMenu add command -command [callback apply_style highlight] \
        -label Highlight -underline 0 -compound left \
        -image [ui::icon draw-highlight.svg $::MENU_ICON_SIZE]
    $ContextMenu add separator
    my make_color_menu $ContextMenu [callback apply_color]
}

oo::define Ste method MakeBindings {} {
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

# Only creates the fonts the first time
oo::define Ste classmethod ensure_fonts fonts {
    variable Initialized
    if {$Initialized} return
    set Initialized 1
    if {$fonts eq ""} { set fonts [my make_default_font_dict] }
    my make_fonts $fonts
}

# Useful for initializing a config file
# size is the base size; if < 8 a sensible default is used
oo::define Ste classmethod make_default_font_dict {{size 0}} {
    if {$size < 8} { set size [font configure TkDefaultFont -size] }
    set fonts [list \
            sans [list [font configure TkDefaultFont -family] $size] \
            serif [list Times $size] \
            mono [list [font configure TkFixedFont -family] $size] \
            casual [list Comic $size] \
            gothic [list Gothic $size] \
            script [list Script $size] \
            ]
    foreach {kind scale} {h1 2 h2 1.5 h3 1.3 h4 1.1} {
        dict set fonts $kind [list [font configure TkDefaultFont -family] \
            [expr {int(round($size * $scale))}]]
    }
    return $fonts
}

# Creates (or reconfigures, so any widgets using them update) the named
# fonts: Roman, Small, Bold, Italic, BoldItalic (sans); SerifRoman, ...,
# MonoRoman, ...; and H1-H4.
# fonts is a dict of kind (sans serif mono h1 h2 h3 h4) -> {family size};
# a missing kind, empty family, or empty size means use the default.
oo::define Ste classmethod make_fonts fonts {
    variable DEFAULT_FAMILIES
    variable BASE_FONT_KINDS
    variable EXTRA_FONT_KINDS
    variable FONT_SPECS
    variable HEADING_KINDS
    variable HEADING_SCALE
    variable FontFor
    set default_size [expr {1 + [font configure TkDefaultFont -size]}]
    foreach kind $BASE_FONT_KINDS {
        lassign [expr {[dict exists $fonts $kind]
                ? [dict get $fonts $kind] : ""}] family size
        if {$family eq ""} {
            set family [dict get $DEFAULT_FAMILIES $kind]
        }
        if {![string is integer -strict $size] || $size <= 0} {
            set size $default_size
        }
        dict set FontFor $kind [list $family $size]
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
    foreach kind $EXTRA_FONT_KINDS {
        lassign [expr {[dict exists $fonts $kind]
                ? [dict get $fonts $kind] : ""}] family size
        if {$family eq ""} { set family [string totitle $kind] }
        if {![string is integer -strict $size] || $size <= 0} {
            set size $default_size
        }
        dict set FontFor $kind [list $family $size]
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
    lassign [dict get $FontFor sans] sans_family sans_size
    foreach kind $HEADING_KINDS {
        lassign [expr {[dict exists $fonts $kind]
                ? [dict get $fonts $kind] : ""}] family size
        if {$family eq ""} { set family $sans_family }
        if {![string is integer -strict $size] || $size <= 0} {
            set size [expr {int(round($sans_size *
                [dict get $HEADING_SCALE $kind]))}]
        }
        dict set FontFor $kind [list $family $size]
        set opts [list -family $family -weight bold -slant roman \
                -size $size]
        set name [string toupper $kind]
        if {$name in [font names]} {
            font configure $name {*}$opts
        } else {
            font create $name {*}$opts
        }
    }
}

oo::define Ste classmethod font_name {kind suffix} {
    switch $kind {
        serif { return Serif$suffix }
        mono { return Mono$suffix }
        casual { return Casual$suffix }
        gothic { return Gothic$suffix }
        script { return Script$suffix }
        default { return $suffix }
    }
}

oo::define Ste classmethod family_for kind {
    variable FontFor
    lindex [dict get $FontFor $kind] 0
}

oo::define Ste classmethod size_for kind {
    variable FontFor
    lindex [dict get $FontFor $kind] 1
}

# dict of {family size} for each of sans serif mono h1 h2 h3 h4
oo::define Ste classmethod fonts {} {
    variable FontFor
    return $FontFor
}

# Tag names starting with this are internal (see refresh_fonts).
oo::define Ste classmethod derived_tag {kind style} {
    return fnt:$kind:$style
}

# Use after the user changes the fonts; fonts is a dict as for make_fonts.
oo::define Ste method set_fonts fonts {
    my make_fonts $fonts
    my ConfigureIndents
    my refresh_fonts [list 1.0 end]
}

oo::define Ste method make_tags {} {
    classvariable URL_UL_COLOR
    classvariable HIGHLIGHT_COLOR
    classvariable COLOR_FOR_TAG
    classvariable DERIVED_STYLES
    classvariable FONT_FOR_STYLE
    classvariable FONT_KINDS_EXCL_SANS
    # The font tags must be the lowest priority; see refresh_fonts.
    $Text tag configure serif -font SerifRoman
    $Text tag configure casual -font CasualRoman
    $Text tag configure gothic -font GothicRoman
    $Text tag configure script -font ScriptRoman
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
    # priority) wherever a non-sans run also has a font style.
    foreach kind $FONT_KINDS_EXCL_SANS {
        foreach style $DERIVED_STYLES {
            $Text tag configure [my derived_tag $kind $style] \
                -font [my font_name $kind [dict get $FONT_FOR_STYLE $style]]
        }
    }
}

oo::define Ste method ConfigureIndents {} {
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

oo::define Ste classmethod filetypes {} {
    variable FILETYPES
    return $FILETYPES
}

oo::define Ste classmethod colors {} {
    variable COLOR_FOR_TAG
    return $COLOR_FOR_TAG
}

oo::define Ste classmethod base_font_kinds {} {
    variable BASE_FONT_KINDS
    return $BASE_FONT_KINDS
}

oo::define Ste classmethod all_font_kinds {} {
    variable ALL_FONT_KINDS
    return $ALL_FONT_KINDS
}

oo::define Ste classmethod extra_font_kinds {} {
    variable EXTRA_FONT_KINDS
    return $EXTRA_FONT_KINDS
}

oo::define Ste classmethod font_heading_kinds {} {
    variable HEADING_KINDS
    return $HEADING_KINDS
}

oo::define Ste classmethod font_body_kinds {} {
    variable FONT_BODY_KINDS
    return $FONT_BODY_KINDS
}

oo::define Ste classmethod font_kinds {} {
    variable FONT_KINDS
    return $FONT_KINDS
}

oo::define Ste method unknown {the_method args} {
    $Text $the_method {*}$args
}

oo::define Ste method focus {} { focus $Text }

oo::define Ste method ttk_frame {} { return $Frame }

oo::define Ste method tk_text {} { return $Text }

oo::define Ste method isempty {} {
    expr {[string trim [$Text get 1.0 end]] eq ""}
}

oo::define Ste method clear {} {
    $Text delete 1.0 end
    $Text edit reset
    $Text edit modified 0
}

oo::define Ste method after_load {{index insert}} {
    my highlight_urls
    my refresh_fonts [list 1.0 end]
    $Text edit reset
    $Text edit modified 0
    if {$index ne "insert"} { $Text mark set insert $index }
    $Text see $index
}

oo::define Ste method first_line {} { string trim [$Text get 1.0 2.0] }

oo::define Ste method highlight_urls {} {
    foreach i [$Text search -all -regexp {(?:https?://|~/)} 1.0] {
        set j [$Text search -regexp {[\s>]} $i]
        if {[$Text get "$j -1 char"] eq "."} {
            set j [$Text index "$j -1 char"]
        }
        $Text tag add url $i $j
    }
}

oo::define Ste method selected {} {
    if {[set indexes [$Text tag ranges sel]] ne ""} {
        return $indexes
    }
    return "[$Text index "insert wordstart"] [$Text index "insert wordend"]"
}

oo::define Ste method get_whole_word {} {
    set a [$Text index "insert linestart"]
    set b [$Text index "insert lineend"]
    set c [$Text index "insert wordstart"]
    set i [$Text search -backwards -exact " " $c "$a -1 char"]
    if {$i eq ""} { set i $a }
    set j [$Text search -exact " " insert "$b +1 char"]
    if {$j eq ""} { set j [$Text index $b] }
    string trim [string trimright [$Text get $i $j] ",;:!?."]
}

oo::define Ste method apply_style style {
    my apply_style_to [my selected] $style
}

oo::define Ste method apply_style_to {indexes style} {
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

oo::define Ste method apply_font kind {
    my apply_font_to [my selected] $kind
}

# kind is sans (the default, no tag), or any of the other body kinds
oo::define Ste method apply_font_to {indexes kind} {
    classvariable HEADING_KINDS
    classvariable FONT_KINDS_EXCL_SANS
    if {$indexes ne ""} {
        # headings have their own fonts (which override sans, serif, and
        # mono) so choosing a family means the text is no longer a heading
        foreach heading $HEADING_KINDS {
            $Text tag remove $heading {*}$indexes
        }
        foreach body $FONT_KINDS_EXCL_SANS {
            $Text tag remove $body {*}$indexes
        }
        if {$kind ne "sans"} { $Text tag add $kind {*}$indexes }
        my refresh_fonts $indexes
        $Text edit modified 1
    }
}

# Tk tags cannot combine fonts: a bold tag's font replaces a serif
# tag's. So for every span of text that is non-sans and also has a
# font-changing style (bold, h1, sub, etc.), add the derived tag
# fnt:<kind>:<style> whose font has both. The derived tags are internal:
# they are never saved or exported (see StripDerived and
# XmlClassifyTag), so this must be called whenever the text's family or
# styles change, or after loading.
# `indexes` is a list of {from to ...} pairs.
oo::define Ste method refresh_fonts indexes {
    classvariable FONT_STYLES
    classvariable DERIVED_STYLES
    classvariable FONT_KINDS_EXCL_SANS
    foreach {from to} $indexes {
        set from [$Text index $from]
        set to [$Text index $to]
        if {[$Text compare $from >= $to]} continue
        foreach kind $FONT_KINDS_EXCL_SANS {
            foreach style $DERIVED_STYLES {
                $Text tag remove [my derived_tag $kind $style] $from $to
            }
        }
        set points [list $from $to]
        foreach tag [concat $FONT_KINDS_EXCL_SANS $FONT_STYLES] {
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
            set kind "" ;# the last (highest priority) family tag wins
            foreach body $FONT_KINDS_EXCL_SANS {
                if {$body in $tags} { set kind $body }
            }
            if {$kind eq ""} continue
            set winner ""
            foreach style $FONT_STYLES {
                if {$style in $tags} { set winner $style }
            }
            # headings have their own fonts so serif/mono don't apply
            if {$winner in $DERIVED_STYLES} {
                $Text tag add [my derived_tag $kind $winner] $a $b
            }
        }
    }
}

oo::define Ste method CompareIndexes {a b} {
    if {[$Text compare $a < $b]} { return -1 }
    if {[$Text compare $a > $b]} { return 1 }
    return 0
}

oo::define Ste method apply_align align {
    set i [$Text index "insert linestart"]
    set j [$Text index "insert lineend"]
    my apply_align_to [list $i $j] $align
}

oo::define Ste method apply_align_to {indexes align} {
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

oo::define Ste method apply_color color {
    my apply_color_to [my selected] $color
}

oo::define Ste method apply_color_to {indexes color} {
    classvariable COLOR_FOR_TAG
    foreach tag [dict keys $COLOR_FOR_TAG] {
        $Text tag remove $tag {*}$indexes
    }
    if {$color ne "black"} {
        $Text tag add $color {*}$indexes
    }
    $Text edit modified 1
}

oo::define Ste method show_indents show {
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
