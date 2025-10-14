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

oo::define TextEdit initialize {
    variable STE_PREFIX
    variable FILETYPES
    variable HIGHLIGHT_COLOR
    variable STRIKE_COLOR
    variable COLOR_FOR_TAG

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
}

oo::define TextEdit constructor {parent {family ""} {size 0}} {
    set FrameName tf#[regsub -all :+ [self] _] ;# unique
    ttk::frame $parent.$FrameName
    set Text [text $parent.$FrameName.txt -undo true -wrap word]
    my MakeBindings
    my make_fonts $family $size
    my make_tags
    ui::scrollize $parent.$FrameName txt vertical
}

oo::define TextEdit method MakeBindings {} {
    bindtags $Text [list $Text Ntext [winfo toplevel $Text] all]
    bind $Text <Control-BackSpace> [callback on_ctrl_bs]
    bind $Text <Double-1> [callback on_double_click]
    bind $Text <Return> [callback on_return]
}

oo::define TextEdit classmethod filetypes {} {
    variable FILETYPES
    return $FILETYPES
}

oo::define TextEdit classmethod colors {} {
    variable COLOR_FOR_TAG
    return $COLOR_FOR_TAG
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

oo::define TextEdit method after_load {} {
    my highlight_urls
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

oo::define TextEdit method get_whole_word {} {
    set a [$Text index "insert linestart"]
    set b [$Text index "insert lineend"]
    set c [$Text index "insert wordstart"]
    set i [$Text search -backwards -exact " " $c "$a -1 char"]
    if {$i eq ""} { set i $c }
    set j [$Text search -exact " " insert "$b +1 char"]
    if {$j eq ""} { set j [$Text index "insert wordend"] }
    string trim [$Text get $i $j]
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
        } elseif {$style eq "sub" && "sub" in $styles} {
            $Text tag remove sub {*}$indexes
        } elseif {$style eq "sup" && "sup" in $styles} {
            $Text tag remove sup {*}$indexes
        } elseif {$style eq "ul" && "ul" in $styles} {
            $Text tag remove ul {*}$indexes
        } elseif {$style eq "strike" && "strike" in $styles} {
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
            set styles [$Text tag names [lindex $indexes 0]]
            if {$align eq "center" && "center" in $styles} {
                $Text tag remove center {*}$indexes
            } elseif {$align eq "right" && "right" in $styles} {
                $Text tag remove right {*}$indexes
            } else {
                if {$align eq "center" && "right" in $styles} {
                    $Text tag remove right {*}$indexes
                } elseif {$align eq "right" && "center" in $styles} {
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
    dict for {key value} $COLOR_FOR_TAG {
        $Text tag configure $key -foreground $value
    }
}

oo::define TextEdit method load txt {
    my clear
    $Text insert end $txt
    my after_load
}

oo::define TextEdit method serialize {{file_format .ste}} {
    classvariable STE_PREFIX
    set txt_dump [$Text dump -text -mark -tag 1.0 "end -1 char"]
    if {$file_format eq ".tkt"} {
        return $txt_dump
    }
    set txt_dumpz [zlib deflate [encoding convertto utf-8 $txt_dump] 9]
    if {$file_format eq ".tktz"} {
        return $txt_dumpz
    }
    return $STE_PREFIX$txt_dumpz ;# .ste
}

oo::define TextEdit method deserialize {raw file_format} {
    my clear
    set txt_dump [my GetTxtDump $raw $file_format]
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

oo::define TextEdit method GetTxtDump {raw file_format} {
    if {$file_format eq ".tkt"} {
        return [encoding convertfrom utf-8 $raw]
    }
    if {$file_format eq ".ste"} {
        set i [string first \n $raw]
        # check here for STE_PREFIX if required
        set raw [string range $raw [incr i] end]
    }
    # elseif $file_format eq ".tktz" then use $raw direct
    encoding convertfrom utf-8 [zlib inflate $raw]
}

oo::define TextEdit method on_ctrl_bs {} {
    set i [$Text index "insert -1 char"]
    set x [$Text index "$i wordstart"]
    set y [$Text index "$x wordend"]
    $Text delete $x $y
}

oo::define TextEdit method on_return {} {
    set i [$Text index "insert -1 char"]
    set i [$Text index "$i linestart"]
    set tab [expr {"NtextTab" in [$Text tag names $i] ? "NtextTab" : ""}]
    set line [$Text get $i "$i lineend"]
    regexp {^\s*•\s+} $line bullet
    regexp {^\s+} $line ws
    if {[info exists bullet] && $bullet ne ""} {
        $Text insert insert \n$bullet $tab
    } elseif {[info exists ws] && $ws ne ""} {
        $Text insert insert \n${ws}
    } else {
        $Text insert insert \n $tab
    }
    return -code break
}

oo::define TextEdit method on_double_click {} {
    set url [my get_whole_word]
    if {[string match ~* $url]} {
        set url file://[file home][string range $url 1 end]
    }
    if {[regexp {^(?:file|https?)://} $url]} {
        my highlight_urls
        util::open_url $url
    }
}
