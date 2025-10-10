# Copyright © 2025 Mark Summerfield. All rights reserved.

# Unique Styles: bold italic bolditalic
# Mixable Styles: highlight COLOR_FOR_TAG listindent[1-3]

package require html 1
package require ntext 1
package require textutil

oo::class create TextEdit {
    variable FrameName
    variable Text
}

oo::define TextEdit initialize {
    variable FILETYPES
    variable HIGHLIGHT_COLOR
    variable COLOR_FOR_TAG

    const FILETYPES {{{ste files} {.ste}} {{tkt files} {.tkt}}}
    const HIGHLIGHT_COLOR yellow ;# use "#FFE119" ?
    const COLOR_FOR_TAG [dict create \
        black "#000000" \
        apricot "#FFD8B1" \
        beige "#FFFAC8" \
        blue "#0000FF" \
        brown "#9A6324" \
        cyan "#42D4F4" \
        green "#3CB44B" \
        grey "#A9A9A9" \
        lavender "#DCB3FF" \
        lime "#BFEF45" \
        magenta "#F032E6" \
        maroon "#800000" \
        mint "#AAFFC3" \
        navy "#000075" \
        olive "#808000" \
        orange "#F58231" \
        pink "#FABEB4" \
        purple "#911EB4" \
        red "#E6194B" \
        teal "#469990" \
        ]
}

oo::define TextEdit classmethod make {parent family size} {
    set theTextEdit [TextEdit new $parent]
    $theTextEdit make_fonts $family $size
    $theTextEdit make_tags
    return $theTextEdit
}

# Use make (above)
oo::define TextEdit constructor parent {
    set FrameName tf#[string range [clock clicks] end-8 end] ;# unique
    ttk::frame $parent.$FrameName
    set Text [text $parent.$FrameName.txt -undo true -wrap word]
    bindtags $Text {$Text Ntext . all}
    ui::scrollize $parent.$FrameName txt vertical
}

oo::define TextEdit classmethod filetypes {} {
    variable FILETYPES
    return $FILETYPES
}

oo::define TextEdit classmethod colornames {} {
    variable COLOR_FOR_TAG
    dict keys $COLOR_FOR_TAG
}

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

oo::define TextEdit method after_load {} {
    $Text edit modified false
    $Text edit reset
    $Text see insert
}

oo::define TextEdit method maybe_undo {} {
    if {[$Text edit canundo]} { $Text edit undo }
}

oo::define TextEdit method maybe_redo {} {
    if {[$Text edit canredo]} { $Text edit redo }
}

oo::define TextEdit method copy {} { tk_textCopy $Text }

oo::define TextEdit method cut {} { tk_textCut $Text }

oo::define TextEdit method paste {} { tk_textPaste $Text }

oo::define TextEdit method selected {} {
    set indexes [$Text tag ranges sel]
    if {$indexes eq ""} {
        set indexes "[$Text index "insert wordstart"]\
                     [$Text index "insert wordend"]"
    }
    return $indexes
}

oo::define TextEdit method apply_style style {
    my apply_style_to [my selected] $style
}

oo::define TextEdit method apply_style_to {indexes style} {
    if {$indexes ne ""} {
        set styles [$Text tag names [lindex $indexes 0]]
        if {$style eq "bold" && "bolditalic" in $styles} {
            $Text tag remove bolditalic {*}$indexes
            $Text tag add italic {*}$indexes
        } elseif {$style eq "italic" && "bolditalic" in $styles} {
            $Text tag remove bolditalic {*}$indexes
            $Text tag add bold {*}$indexes
        } elseif {($style eq "bold" && "italic" in $styles) ||
                  ($style eq "italic" && "bold" in $styles)} {
            $Text tag remove bold {*}$indexes
            $Text tag remove italic {*}$indexes
            $Text tag add bolditalic {*}$indexes
        } elseif {$style eq "bold" && "bold" in $styles} {
            $Text tag remove bold {*}$indexes
        } elseif {$style eq "italic" && "italic" in $styles} {
            $Text tag remove italic {*}$indexes
        } elseif {$style eq "highlight" && "highlight" in $styles} {
            $Text tag remove highlight {*}$indexes
        } else {
            $Text tag add $style {*}$indexes
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

oo::define TextEdit method make_fonts {family size} {
    classvariable COLOR_FOR_TAG
    foreach name {Sans Bold Italic BoldItalic} {
        catch { font delete $name }
    }
    font create Sans -family $family -size $size
    font create Bold -family $family -size $size -weight bold
    font create Italic -family $family -size $size -slant italic
    font create BoldItalic -family $family -size $size -weight bold \
        -slant italic
    $Text configure -font Sans -foreground [dict get $COLOR_FOR_TAG black]
}

oo::define TextEdit method make_tags {} {
    classvariable HIGHLIGHT_COLOR
    classvariable COLOR_FOR_TAG
    $Text tag configure bold -font Bold
    $Text tag configure italic -font Italic
    $Text tag configure bolditalic -font BoldItalic
    $Text tag configure highlight -background $HIGHLIGHT_COLOR
    dict for {key value} $COLOR_FOR_TAG {
        $Text tag configure $key -foreground $value
    }
    const WIDTH [font measure Sans "•. "]
    set indent [font measure Sans "nnnn"]
    $Text tag configure listindent1 -lmargin1 0 -lmargin2 $WIDTH
    $Text tag configure listindent2 -lmargin1 $indent \
        -lmargin2 [expr {$indent + $WIDTH}]
    set indent [expr {$indent * 2}]
    $Text tag configure listindent3 -lmargin1 $indent \
        -lmargin2 [expr {$indent + $WIDTH}]
}

oo::define TextEdit method load txt {
    my clear
    $Text insert end $txt
    my after_load
}

oo::define TextEdit method serialize {{compress true}} {
    set txt_dump [$Text dump -text -mark -tag 1.0 "end -1 char"]
    if {$compress} {
        return STE1\n[zlib deflate [encoding convertto utf-8 $txt_dump] 9]
    } else {
        return $txt_dump
    }
}

oo::define TextEdit method deserialize txt_dumpz {
    my clear
    set i [string first \n $txt_dumpz]
    set prefix [string range $txt_dumpz 0 $i]
    set raw [string range $txt_dumpz [incr i] end]
    if {[string match STE* $prefix]} {
        set txt_dump [encoding convertfrom utf-8 [zlib inflate $raw]]
    } else {
        set txt_dump [encoding convertfrom utf-8 $txt_dumpz]
    }
    array set tags {}
    set insert_index end
    set pending [list]
    foreach {key value index} $txt_dump {
        switch $key {
            text { $Text insert $index $value }
            mark { 
                switch $value {
                    current {}
                    insert { set insert_index $index}
                    default { $Text mark set $value $index }
                }
            }
            tagon {
                set tags($value) $index
                lappend pending $value
            }
            tagoff {
                $Text tag add $value $tags($value) $index
                lpop pending
            }
        }
    }
    while {[llength $pending]} {
        set value [lpop pending]
        $Text tag add $value $tags($value) end
    }
    $Text mark set insert $insert_index 
    my after_load
}
