# Copyright © 2025 Mark Summerfield. All rights reserved.

# Unique Styles: bold italic bolditalic COLOR_FOR_TAG
# Mixable Styles: highlight indent[1-3]

package require html 1
package require ntext 1
package require textutil

oo::class create TextEdit { variable Text }

oo::define TextEdit initialize {
    variable HIGHLIGHT_COLOR
    variable COLOR_FOR_TAG

    const HIGHLIGHT_COLOR yellow ;# use "#FFE119" ?
    const COLOR_FOR_TAG [dict create \
        black "#000000" \
        apricot "#FFD8B1" \
        beige "#FFFAC8" \
        blue "#4363D8" \
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

oo::define TextEdit classmethod make {panel family size} {
    set theTextEdit [TextEdit new $panel]
    $theTextEdit make_fonts $family $size
    $theTextEdit make_tags
    return $theTextEdit
}

# Use make (above)
oo::define TextEdit constructor panel {
    ttk::frame $panel.tf
    set Text [text $panel.tf.txt -undo true -wrap word]
    bindtags $Text {$Text Ntext . all}
    ui::scrollize $panel.tf txt vertical
}

oo::define TextEdit method textedit {} { return $Text }

oo::define TextEdit method clear {} {
    $Text delete 1.0 end
    $Text edit modified false
    $Text edit reset
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

oo::define TextEdit method insert_char ch { $Text insert insert $ch }

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

oo::define TextEdit method colors {} {
    classvariable COLOR_FOR_TAG
    return $COLOR_FOR_TAG
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
    set indent [font measure Sans "xxxx"]
    $Text tag configure indent1 -lmargin1 $indent \
        -lmargin2 [expr {$indent + $WIDTH}]
    set indent [expr {$indent * 2}]
    $Text tag configure indent2 -lmargin1 $indent \
        -lmargin2 [expr {$indent + $WIDTH}]
    set indent [expr {$indent * 3}]
    $Text tag configure indent3 -lmargin1 $indent \
        -lmargin2 [expr {$indent + $WIDTH}]
}

oo::define TextEdit method serialize {} {
    set txt_dump [$Text dump -text -mark -tag 1.0 "end -1 char"]
    zlib deflate [encoding convertto utf-8 $txt_dump] 9
}

oo::define TextEdit method deserialize txt_dumpz {
    set txt_dump [encoding convertfrom utf-8 [zlib inflate $txt_dumpz]]
    array set tags {}
    set current_index end
    set insert_index end
    set pending [list]
    foreach {key value index} $txt_dump {
        switch $key {
            text { $Text insert $index $value }
            mark { 
                switch $value {
                    current { set current_index $index }
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
    $Text mark set current $current_index
    $Text mark set insert $insert_index 
}

oo::define TextEdit method as_text {} {
    set lines [list]
    foreach line [split [$Text get 1.0 end] \n] {
        lappend lines [textutil::adjust $line -length 76]
    }
    join $lines \n
}

oo::define TextEdit method as_html filename {
    set txt_dump [$Text dump -text -mark -tag 1.0 "end -1 char"]
    set title [html::html_entities [file rootname [file tail $filename]]]
    set out [list "<html>\n<head><title>$title</title></head>\n<body>\n"]
    set pending [list]
    set flip true
    foreach {key value index} $txt_dump {
        switch $key {
            text {
                if {$value eq "\n"} {
                    lappend out \n</p>\n\n
                    set flip true
                } else {
                    if {$flip} {
                        lappend out <p>\n
                        set flip false
                    }
                    lappend out [html::html_entities \
                        [string trim $value \n]]
                    
                }
            }
            tagon {
                lappend out [my HtmlOn $value]
                lappend pending $value
            }
            tagoff {
                lappend out [my HtmlOff $value]
                lpop pending
            }
        }
    }
    while {[llength $pending]} {
        set value [lpop pending]
        lappend out [my HtmlOff $value]
    }
    lappend out "\n</p>\n</body>\n</html>\n"
    join $out ""
}

oo::define TextEdit method HtmlOn tag {
    classvariable HIGHLIGHT_COLOR
    classvariable COLOR_FOR_TAG
    switch $tag {
        bold { return <b> }
        italic { return <i> }
        bolditalic { return <b><i> }
        highlight { return "<span style=\"background-color:\
            $HIGHLIGHT_COLOR;\">" }
        indent1 { return "<div style=\"text-indent: 2em;\">" }
        indent2 { return "<div style=\"text-indent: 4em;\">" }
        indent3 { return "<div style=\"text-indent: 6em;\">" }
        sel {}
        default {
            return "<span style=\"color: [dict get $COLOR_FOR_TAG $tag];\">"
        }
    }
}

oo::define TextEdit method HtmlOff tag {
    switch $tag {
        bold { return </b> }
        italic { return </i> }
        bolditalic { return </i></b> }
        highlight { return </span> }
        indent1 { return </div> }
        indent2 { return </div> }
        indent3 { return </div> }
        sel {}
        default { return </span> }
    }
}
