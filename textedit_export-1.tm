# Copyright © 2025 Mark Summerfield. All rights reserved.

package require lambda 1
package require textutil

oo::define TextEdit method as_text {} {
    set lines [list]
    foreach line [split [$Text get 1.0 end] \n] {
        lappend lines [textutil::adjust $line -length 76]
    }
    join $lines \n
}

oo::define TextEdit method as_html_orig filename {
    set txt_dump [$Text dump -text -mark -tag 1.0 "end -1 char"]
    set title [html::html_entities [file rootname [file tail $filename]]]
    set out [list "<html>\n<head><title>$title</title></head>\n<body>\n"]
    set pending [list]
    set flip true
    set tabize [lambda x {string repeat "&nbsp;" \
        [expr {4 * [string length $x]}]}]
    foreach {key value index} $txt_dump {
        switch $key {
            text {
                if {$value eq "\n"} {
                    lappend out </p>\n
                    set flip true
                } else {
                    if {$flip} {
                        lappend out \n<p>\n
                        set flip false
                    }
                    lappend out [regsub -command {^\s+} \
                        [html::html_entities $value] $tabize]
                    
                }
            }
            tagon {
                if {$flip} {
                    lappend out \n<p>\n
                    set flip false
                }
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
    my FixupItems out
    set lines [split [join $out ""] \n]
    my FixupLines lines
    join $lines \n
}

oo::define TextEdit method FixupItems out {
    upvar 1 $out out_
    for {set i 0} {$i < [llength $out_]} {incr i} {
        set item [lindex $out_ $i]
        if {[string match ~* $item]} {
            set item file://[file home][string range $item 1 end]
        }
        if {[regexp {^(?:file|https?)://} $item]} {
            set url $item
            if {[string index $url end] eq "."} {
                set url [string range $url 0 end-1]
            }
            ledit out_ $i $i "<a href=\"$url\">$item</a>"
        }
    }
}

oo::define TextEdit method FixupLines lines {
    upvar 1 $lines lines_
    for {set i 0} {$i < [llength $lines_]} {incr i} {
        set line [lindex $lines_ $i]
        if {[regexp {^(</?li>)?(&bull;|•)\s} $line]} {
            ledit lines_ $i $i [regsub {^(</?li>)?(&bull;|•)\s} $line \
                "<li>"]
        }
    }
}

oo::define TextEdit method HtmlOn tag {
    classvariable STRIKE_COLOR
    classvariable HIGHLIGHT_COLOR
    classvariable COLOR_FOR_TAG
    switch $tag {
        bindent0 - bindent1 { return <li> }
        bold { return <b> }
        bolditalic { return <b><i> }
        center { return "<div style=\"text-align: center;\">" }
        italic { return <i> }
        highlight { return "<span style=\"background-color:\
            $HIGHLIGHT_COLOR;\">" }
        left { return "" }
        NtextTab { return <br> }
        right { return "<div style=\"text-align: right;\">" }
        sel {}
        strike { return <del> }
        sub { return <sub> }
        sup { return <sup> }
        ul - underline { return <u> }
        url {
            return "<span style=\"text-decoration: underline;\
                text-decoration-color: #FF8C00\">"
        }
        default {
            if {[set color [dict getdef $COLOR_FOR_TAG $tag ""]] ne ""} {
                return "<span style=\"color: $color;\">"
            }
            puts "unhandled tag '$tag'"
        }
    }
}

oo::define TextEdit method HtmlOff tag {
    switch $tag {
        bindent0 - bindent1 { return </li> }
        bold { return </b> }
        bolditalic { return </i></b> }
        center { return </div> }
        italic { return </i> }
        highlight { return </span> }
        left { return "" }
        NtextTab { return "" }
        right { return </div> }
        sel {}
        strike { return </del> }
        sub { return </sub> }
        sup { return </sup> }
        ul - underline { return </u> }
        url { return </span> }
        default { return </span> }
    }
}

oo::define TextEdit method as_html filename {
    set title [html::html_entities [file rootname [file tail $filename]]]
    set out [list "<html>\n<head><title>$title</title></head>\n<body>\n"]
    lassign [my get_tag_dicts] tags_on tags_off
    foreach para [lseq 1 to [$Text count -lines 1.0 end]] {
        set line ""
        foreach char [lseq 0 to [$Text count -chars $para.0 $para.end]] {
            set index $para.$char
            set tag_on [dict getdef $tags_on $index ""]
            set tag_off [dict getdef $tags_off $index ""]
            if {[set c [$Text get $index]] eq "\n"} {
                set c ""
            } else {
                set c [html::html_entities $c]
            }
            if {$tag_off ne ""} {
            }
            if {$tag_on ne ""} {
            }
            if {$c ne ""} { lappend line $c }
        }
        if {[set line [join $line ""]] ne ""} {
            lappend out "<p>\n$line\n</p>\n"
        }
    }
    lappend out "</body>\n</html>\n"
    join $out ""
}

oo::define TextEdit method get_tag_dicts {} {
    set tags_on [list]
    set tags_off [list]
    foreach tag [$Text tag names] {
        if {$tag ne "left"} {
            foreach {from to} [$Text tag ranges $tag] {
                lassign [split $from .] frompara fromchar
                lappend tags_on [Tag new $tag $frompara $fromchar]
                lassign [split $to .] topara tochar
                lappend tags_off [Tag new $tag $topara $tochar]
            }
        }
    }
    set tags_on [my merge_tags $tags_on]
    set tags_off [my merge_tags $tags_off]
    list [my dict_from_tag_list $tags_on] [my dict_from_tag_list $tags_off]
}

oo::define TextEdit classmethod merge_tags old {
    set new [list]
    set prev ""
    foreach tag [lsort -command tags_compare $old] {
        if {$prev ne ""} {
            if {[$prev para] == [$tag para] && \
                    [$prev char] == [$tag char]} {
                $prev append [$tag tag]
            } else {
                lappend new $tag
                set prev $tag
            }
        } else {
            lappend new $tag
            set prev $tag
        }
    }
    return $new
}

oo::define TextEdit classmethod dict_from_tag_list tag_list {
    set tag_dict [dict create]
    foreach tag $tag_list {
        dict set tag_dict [$tag para].[$tag char] $tag
    }
    return $tag_dict
}

proc tags_compare {t u} {
    set paraT [$t para]
    set paraU [$u para]
    if {$paraT < $paraU} { return -1 }
    if {$paraT > $paraU} { return 1 }
    set charT [$t char]
    set charU [$u char]
    if {$charT < $charU} { return -1 }
    if {$charT > $charU} { return 1 }
    string compare [$t tag] [$u tag]
}

oo::class create Tag {
    variable Tags
    variable Para
    variable Char

    constructor {tag para char} {
        set Tags [list $tag]
        set Para $para
        set Char $char
    }

    method tag {} { return [lindex $Tags 0] }
    method tags {} { return $Tags }
    method append tag { lappend Tags $tag }
    method para {} { return $Para }
    method char {} { return $Char }

    method to_string {} { return "Tag: $Para.$Char $Tags" }
}
