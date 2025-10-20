# Copyright © 2025 Mark Summerfield. All rights reserved.

# Unique Styles: bold italic bolditalic
# Mixable Styles: highlight COLOR_FOR_TAG listindent[1-3]

package require html 1
package require ntext 1
package require textutil
package require util

oo::class create TextEdit {
    variable FrameName
    variable Text
}

package require textedit_actions
package require textedit_export
package require textedit_import
package require textedit_serialize

oo::define TextEdit initialize {
    variable STE_PREFIX
    variable FILETYPES
    variable HIGHLIGHT_COLOR
    variable STRIKE_COLOR
    variable COLOR_FOR_TAG
    variable TAG_FOR_HTML_COLOR

    const STE_PREFIX STE1\n
    const FILETYPES {{{ste files} {.ste}} {{tkt files} {.tkt}} \
        {{compressed tkt files} {.tktz}}}
    const STRIKE_COLOR #FF8C00 ;# orange
    const HIGHLIGHT_COLOR yellow
    ;# Any changes to COLOR_FOR_TAG must be reflected in App make_color_menu
    const COLOR_FOR_TAG [dict create \
        black "#000000" \
        grey "#555555" \
        navy "#000075" \
        blue "#0000FF" \
        lavender "#6767E0" \
        cyan "#007272" \
        teal "#469990" \
        olive "#676700" \
        green "#009C00" \
        lime "#608000" \
        maroon "#800000" \
        brown "#9A6324" \
        gold "#9A8100" \
        orange "#CD8400" \
        red "#FF0000" \
        pink "#FF5B77" \
        purple "#911EB4" \
        magenta "#F032E6" \
        ]
    ;# From most recent .nb2 format
    const TAG_FOR_HTML_COLOR [dict create \
        "#000000" black \
        "#800000" maroon \
        "#AA6E28" brown \
        "#808000" olive \
        "#008080" teal \
        "#000080" navy \
        "#F58230" orange \
        "#8A8A00" gold \
        "#728420" lime \
        "#008000" green \
        "#268282" cyan \
        "#0000FF" blue \
        "#911EB4" purple \
        "#800080" magenta \
        "#808080" grey \
        "#876773" pink \
        "#665877" lavender \
        "#5C8A69" lime \
        "#77745D" brown \
        "#8A7461" pink \
        ]

}

oo::define TextEdit constructor {parent {family ""} {size 0}} {
    set FrameName tf#[regsub -all :+ [self] _] ;# unique
    if {![string match *. $parent]} { set parent $parent. }
    ttk::frame $parent$FrameName
    set Text [text $parent$FrameName.txt -undo true -wrap word]
    my MakeBindings
    my make_fonts $family $size
    my make_tags
    ui::scrollize $parent$FrameName txt vertical
}

oo::define TextEdit method MakeBindings {} {
    bindtags $Text [list $Text Ntext [winfo toplevel $Text] all]
    bind $Text <BackSpace> [callback on_bs]
    bind $Text <Control-BackSpace> [callback on_ctrl_bs]
    bind $Text <Double-1> [callback on_double_click]
    bind $Text <Return> [callback on_return]
    bind $Text <Tab> [callback on_tab]
    bind $Text <'> [callback on_single_quote]
}

oo::define TextEdit method make_fonts {family size} {
    foreach name {Sans Bold Italic BoldItalic} {
        catch { font delete $name }
    }
    font create Sans -family $family -size $size
    font create Small -family $family \
        -size [expr {int(round($size * 0.75))}]
    font create Bold -family $family -size $size -weight bold
    font create Italic -family $family -size $size -slant italic
    font create BoldItalic -family $family -size $size -weight bold \
        -slant italic
    set tab [expr {4 * [font measure Sans n]}]
    $Text configure -font Sans -tabstyle wordprocessor -tabs "$tab left"
}

oo::define TextEdit method make_tags {} {
    classvariable STRIKE_COLOR
    classvariable HIGHLIGHT_COLOR
    classvariable COLOR_FOR_TAG
    $Text tag configure sub -font Small -offset -3p
    $Text tag configure sup -font Small -offset 3p
    $Text tag configure ul -underline true
    $Text tag configure strike -overstrike true -overstrikefg #FF1A1A
    $Text tag configure center -justify center
    $Text tag configure right -justify right
    $Text tag configure url -underline true -underlinefg $STRIKE_COLOR
    $Text tag configure bold -font Bold
    $Text tag configure italic -font Italic
    $Text tag configure bolditalic -font BoldItalic
    $Text tag configure highlight -background $HIGHLIGHT_COLOR
    set bwidth [font measure Sans "• "]
    set twidth [font measure Sans "nnnn"]
    # DEBUG: -background #E0FFFF
    $Text tag configure bindent0 -lmargin2 $bwidth
    # DEBUG: -background #ADFFFF
    $Text tag configure bindent1 -lmargin1 $twidth \
        -lmargin2 [expr {$twidth + $bwidth}]
    dict for {key value} $COLOR_FOR_TAG {
        $Text tag configure $key -foreground $value
    }
}

oo::define TextEdit classmethod filetypes {} {
    variable FILETYPES
    return $FILETYPES
}

oo::define TextEdit classmethod colors {} {
    variable COLOR_FOR_TAG
    return $COLOR_FOR_TAG
}

oo::define TextEdit classmethod html_colors {} {
    variable TAG_FOR_HTML_COLOR
    return $TAG_FOR_HTML_COLOR
}

oo::define TextEdit method unknown {method_name args} {
    $Text $method_name {*}$args
}

oo::define TextEdit method focus {} { focus $Text }

oo::define TextEdit method framename {} { return $FrameName }

oo::define TextEdit method textedit {} { return $Text }

oo::define TextEdit method isempty {} {
    expr {[string trim [$Text get 1.0 end]] eq ""}
}

oo::define TextEdit method clear {} {
    $Text delete 1.0 end
    $Text edit modified false
    $Text edit reset
}

oo::define TextEdit method highlight_urls {} {
    foreach i [$Text search -all -regexp {(?:https?://|~/)} 1.0] {
        set j [$Text search -regexp {[\s>]} $i]
        $Text tag add url $i $j
    }
}

oo::define TextEdit method after_load {{index insert}} {
    my highlight_urls
    $Text edit modified false
    $Text edit reset
    if {$index ne "insert"} { $Text mark set insert $index }
    $Text see $index
}

oo::define TextEdit method selected {} {
    set indexes [$Text tag ranges sel]
    if {$indexes eq ""} {
        set indexes "[$Text index "insert wordstart"]\
                     [$Text index "insert wordend"]"
    }
    return $indexes
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
        } else {
            $Text tag add $style {*}$indexes
        }
        $Text edit modified true
    }
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
        $Text edit modified true
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
    $Text edit modified true
}
