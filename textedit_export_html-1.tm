# Copyright © 2025 Mark Summerfield. All rights reserved.

oo::define TextEdit method as_html title {
    set out [list "<html>\n<head><title>$title</title></head>\n<body>\n"]
    lassign [my GetTagDicts] tags_on tags_off
    foreach para [lseq 1 to [$Text count -lines 1.0 end]] {
        set prefix "<p>"
        set line ""
        foreach char [lseq 0 to [$Text count -chars $para.0 $para.end]] {
            set index $para.$char
            set tag_on [dict getdef $tags_on $index ""]
            set tag_off [dict getdef $tags_off $index ""]
            if {[set c [$Text get $index]] eq "\n"} {
                set c " "
            } else {
                set c [html::html_entities $c]
            }
            if {$tag_on ne ""} {
                foreach tag [$tag_on tags] {
                    lappend line [my HtmlTagOn prefix $tag]
                }
            }
            if {$c ne ""} { lappend line $c }
            if {$tag_off ne ""} {
                foreach tag [$tag_off tags] {
                    lappend line [my HtmlTagOff $tag]
                }
            }
        }
        if {[set line [string trim [join $line ""]]] ne ""} {
            lappend out "$prefix\n$line\n</p>\n"
        }
    }
    lappend out "</body>\n</html>\n"
    my HtmlFixUps [join $out ""]
}

oo::define TextEdit method HtmlTagOn {prefix tag} {
    upvar 1 $prefix prefix_
    classvariable HIGHLIGHT_COLOR
    classvariable COLOR_FOR_TAG
    switch $tag {
        bindent0 - bindent1 - bindent2 { set prefix_ <ul><li> ; return }
        nindent0 - nindent1 - nindent2 { set prefix_ <ol><li> ; return }
        tindent0 - tindent1 - tindent2 {
            set prefix_ "<ul style=\"list-style-type: none; padding: 0;\
                margin: 0;\"><li>"
            return
        }
        center {
            set prefix_ "<p style=\"text-align: center;\">"
            return
        }
        right {
            set prefix_ "<p style=\"text-align: right;\">"
            return
        }
        bold { return <b> }
        bolditalic { return <b><i> }
        italic { return <i> }
        highlight { return "<span style=\"background-color:\
            $HIGHLIGHT_COLOR;\">" }
        strike { return <del> }
        sub { return <sub> }
        sup { return <sup> }
        ul - underline { return <u> }
        url { return }
        default {
            if {[set color [dict getdef $COLOR_FOR_TAG $tag ""]] ne ""} {
                return "<span style=\"color: $color;\">"
            }
            puts "unhandled tag '$tag'"
            return
        }
    }
}

oo::define TextEdit method HtmlTagOff tag {
    classvariable COLOR_FOR_TAG
    switch $tag {
        bindent0 - bindent1 - bindent2 { return </li></ul> }
        nindent0 - nindent1 - nindent2 { return </li></ol> }
        tindent0 - tindent1 - tindent2 { return </li></ul> }
        bold { return </b> }
        bolditalic { return </i></b> }
        italic { return </i> }
        highlight { return </span> }
        strike { return </del> }
        sub { return </sub> }
        sup { return </sup> }
        ul - underline { return </u> }
        url { return }
        default {
            if {[set color [dict getdef $COLOR_FOR_TAG $tag ""]] ne ""} {
                return "</span>"
            }
            return
        }
    }
}

oo::define TextEdit method HtmlFixUps out {
    set out [regsub -all -command {\m(?:file|https?)://[^\s<]+} $out \
        TextEditHtmlReplaceUrl]
    set out [regsub -all -command {~/[^\s<]+} $out TextEditHtmlReplaceTilde]
    set out [regsub -all {</p>\n<p>\n</span>\n</p>} $out "</span>\n</p>"]
    set out [regsub -all {<ol><li>\s*[1-9]\.\s+(.*?)</p>} \
        $out "<ol><li>\\1</li></ol>"]
    set out [regsub -all {<ol><li>\s+[1-9]\.?</li></ol>\.?\s+(.*?)</p>} \
        $out "<ol><li>\\1</li></ol>"]
    set out [regsub -all {<p>\s+[1-9]\.\s+(.*?)</p>} $out \
        "<ol><li>\\1</li></ol>"]
    set out [regsub -all {<li>\s+</li></ul>([^\n]+(?:</p>)?)} $out \
        "<li>\\1</li></ul>"]
    set out [regsub -all {(?:<li>|<p>)\n?&bull;\s+([^\n]+(?:</p>)?)} $out \
        "<ul><li>\\1</li></ul>"]
    return $out
}

proc TextEditHtmlReplaceTilde localfile {
    lassign [TextEditUrlAndDot $localfile] localfile dot
    set url file://[file home][string range $localfile 1 end]
    return "<a href=\"$url\"\>$localfile</a>$dot"
        
}

proc TextEditHtmlReplaceUrl url {
    lassign [TextEditUrlAndDot $url] url dot
    set i [string first / $url]
    set name [string range $url [incr i 2] end]
    if {[string match */ $name]} { set name [string range $name 0 end-1] }
    return "<a href=\"$url\"\>$name</a>$dot"
}

proc TextEditUrlAndDot url {
    set dot ""
    if {[string match *. $url]} {
        set url [string range $url 0 end-1]
        set dot .
    }
    list $url $dot
}
