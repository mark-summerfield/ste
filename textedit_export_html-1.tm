# Copyright © 2025 Mark Summerfield. All rights reserved.
#
# Adpated from Claude AI-generated code (all comments bar this are from
# the AI).
#
# Self-contained, round-trippable HTML export. Pairs with from_html in
# textedit_import_html-1.tm.
#
# Structurally this is the same walk as XmlFromDump (textedit_export_
# xml-1.tm) -- one <p> per line, tag-state runs -- and reuses that file's
# tag-classification/priority-resolution helpers (XmlClassifyTag,
# XmlResolveTag, xml_escape, xml_escape_attr) since those are format-
# agnostic. The difference is purely presentational: rather than
# inventing justify=/indent=/level= XML attributes, HTML just uses the
# real Tk tag names directly as CSS class names (<p class="right">,
# <span class="bold red">, <p class="bindent1">), styled by an embedded
# <style> block built from the exact values in make_tags/COLOR_FOR_TAG --
# so this depends on textedit_export_xml-1.tm being loaded first.
#
# `url` runs become <a class="url ..." href="TEXT">TEXT</a> (href is
# just the run's own text, since ste's `url` tag is applied to literal
# URL text, not a separate target) -- real, clickable links, still with
# any other simultaneous tags (bold, a colour, ...) as extra classes.
#
# Marks become a void custom element, <ste-mark data-name="NAME"/>,
# rather than co-opting <a name="..."> (obsolete in HTML5) or <span>
# (which would be ambiguous with untagged marker spans).
#
# Blank lines are genuinely empty <p></p> (not "<p>&nbsp;</p>") so a
# round trip through from_html doesn't inject a stray character -- a
# `p:empty { min-height: ... }` CSS rule keeps them visible in a browser.

oo::define TextEdit method as_html title {
    set dump [$Text dump -text -mark -tag 1.0 "end -1 char"]
    my HtmlFromDump $dump $title
}

oo::define TextEdit method HtmlFromDump {dump title} {
    set inlineTags {}     ;# ordered list of currently-active inline tags
    set justifyStack {}   ;# stack of currently-active justify tags
    set indentStack {}    ;# stack of currently-active indent tags

    # See textedit_export_xml-1.tm::XmlFromDump for why these are seeded
    # lazily rather than immediately at paragraph-flush time (same-index
    # tagoff/tagon pairs at a level-transition boundary, e.g.
    # "tagoff bindent0 X.0 tagon bindent1 X.0").
    set justifySeen {}
    set indentSeen {}
    set pendingSeed 0

    set paraChildren {}   ;# serialized child fragments of current para
    set havePara 0         ;# has *anything* happened since para started?

    set body {}

    foreach {key value index} $dump {
        switch -- $key {
            tagon {
                switch -- [my XmlClassifyTag $value] {
                    skip {}
                    justify {
                        lappend justifyStack $value
                        if {$value ni $justifySeen} {
                            lappend justifySeen $value
                        }
                    }
                    indent {
                        lappend indentStack $value
                        if {$value ni $indentSeen} {
                            lappend indentSeen $value
                        }
                    }
                    default {
                        if {$value ni $inlineTags} {
                            lappend inlineTags $value
                        }
                    }
                }
            }
            tagoff {
                switch -- [my XmlClassifyTag $value] {
                    skip {}
                    justify {
                        set p [lsearch -exact $justifyStack $value]
                        if {$p >= 0} {
                            set justifyStack [lreplace $justifyStack $p $p]
                        }
                    }
                    indent {
                        set p [lsearch -exact $indentStack $value]
                        if {$p >= 0} {
                            set indentStack [lreplace $indentStack $p $p]
                        }
                    }
                    default {
                        set p [lsearch -exact $inlineTags $value]
                        if {$p >= 0} {
                            set inlineTags [lreplace $inlineTags $p $p]
                        }
                    }
                }
            }
            mark {
                if {$value in {insert current}} continue
                if {$pendingSeed} {
                    set justifySeen $justifyStack
                    set indentSeen $indentStack
                    set pendingSeed 0
                }
                lappend paraChildren [my HtmlMakeMark $value]
                set havePara 1
            }
            text {
                set remaining $value
                while {1} {
                    set nlPos [string first "\n" $remaining]
                    if {$nlPos < 0} {
                        if {$remaining ne {}} {
                            if {$pendingSeed} {
                                set justifySeen $justifyStack
                                set indentSeen $indentStack
                                set pendingSeed 0
                            }
                            lappend paraChildren [my HtmlMakeRun \
                                    $remaining $inlineTags]
                            set havePara 1
                        }
                        break
                    }
                    set chunk [string range $remaining 0 \
                            [expr {$nlPos - 1}]]
                    if {$chunk ne {}} {
                        if {$pendingSeed} {
                            set justifySeen $justifyStack
                            set indentSeen $indentStack
                            set pendingSeed 0
                        }
                        lappend paraChildren [my HtmlMakeRun $chunk \
                                $inlineTags]
                    }
                    if {$pendingSeed} {
                        set justifySeen $justifyStack
                        set indentSeen $indentStack
                        set pendingSeed 0
                    }
                    append body [my HtmlMakePara $justifySeen $indentSeen \
                            $paraChildren]
                    set paraChildren {}
                    set havePara 0
                    set justifySeen {}
                    set indentSeen {}
                    set pendingSeed 1
                    set remaining [string range $remaining \
                            [expr {$nlPos + 1}] end]
                }
            }
            default {
                # Forward-compatible passthrough for events HtmlMakeRun/
                # HtmlMakeMark don't know about (e.g. image/window, if
                # ste ever grows that support).
                if {$pendingSeed} {
                    set justifySeen $justifyStack
                    set indentSeen $indentStack
                    set pendingSeed 0
                }
                lappend paraChildren "<ste-event data-key=\"[my \
                    xml_escape_attr $key]\" \
                    data-value=\"[my xml_escape_attr \
                    $value]\" data-index=\"$index\"/>"
                set havePara 1
            }
        }
    }

    if {$pendingSeed} {
        set justifySeen $justifyStack
        set indentSeen $indentStack
        set pendingSeed 0
    }
    if {$havePara} {
        append body [my HtmlMakePara $justifySeen $indentSeen $paraChildren]
    }

    my HtmlDocument $title $body
}

# Build a <span>/<a> element (or bare escaped text if no tags are
# active). `url` gets a real, clickable <a href="..."> instead of <span>
# -- ste's url tag is applied to literal URL text, so the text itself
# *is* the target.
oo::define TextEdit method HtmlMakeRun {text tags} {
    if {[llength $tags] == 0} {
        return [my xml_escape $text]
    }
    set cls [my xml_escape_attr [join $tags { }]]
    if {"url" in $tags} {
        return "<a class=\"$cls\" href=\"[my xml_escape_attr \
            $text]\">[my xml_escape $text]</a>"
    }
    return "<span class=\"$cls\">[my xml_escape $text]</span>"
}

oo::define TextEdit method HtmlMakeMark name {
    return "<ste-mark data-name=\"[my xml_escape_attr $name]\"/>"
}

# Build a <p ...>...</p> (or empty <p></p>). Unlike XmlMakePara, the
# resolved justify/indent tags are used directly as class names -- no
# translation to kind/level attributes needed, since the CSS in
# HtmlDocument targets the raw tag names (.right, .bindent1, ...).
oo::define TextEdit method HtmlMakePara {justifySeen indentSeen \
        paraChildren} {
    set classes {}
    set justify [my XmlResolveTag $justifySeen {center right}]
    if {$justify ne {}} { lappend classes $justify }
    set indentTag {}
    if {[llength $indentSeen]} {
        set kinds {}
        foreach indent $indentSeen {
            regexp {^(bindent|tindent|nindent)[0-9]+$} $indent _ kind
            if {$kind ni $kinds} { lappend kinds $kind }
        }
        set winningKind [my XmlResolveTag $kinds {tindent bindent nindent}]
        foreach indent $indentSeen {
            if {[string match "${winningKind}*" $indent]} {
                set indentTag $indent
                break
            }
        }
    }
    if {$indentTag ne {}} { lappend classes $indentTag }
    set clsAttr {}
    if {[llength $classes]} {
        set clsAttr " class=\"[my xml_escape_attr [join $classes { }]]\""
    }
    return "<p$clsAttr>[join $paraChildren {}]</p>\n"
}

# Wrap the accumulated <p>...</p> body in a full, self-contained HTML5
# document with an embedded stylesheet built from the exact values
# make_tags/COLOR_FOR_TAG use, so a plain browser renders it the same
# way $Text does.
oo::define TextEdit method HtmlDocument {title body} {
    classvariable HIGHLIGHT_COLOR
    classvariable URL_UL_COLOR
    classvariable COLOR_FOR_TAG

    set css {}
    append css "body{font-family:sans-serif;font-size:1em;line-height:1.5;"
    append css "max-width:50em;margin:2em auto;padding:0\
        1em;color:#000;background:#fff}\n"
    append css "p{margin:0 0 .6em 0}\n"
    append css "p:empty{min-height:1em}\n"
    append css ".center{text-align:center}\n.right{text-align:right}\n"
    # Hanging indent, matching make_tags' -lmargin1 (first line) /
    # -lmargin2 (wrapped lines) pairs: lmargin1 is one unit less than
    # lmargin2, so text-indent is a fixed -1 unit relative to margin-left.
    foreach kind {bindent tindent nindent} {
        for {set n 0} {$n <= 2} {incr n} {
            set ml [expr {($n + 1) * 1.5}]
            append css \
                ".$kind$n\{margin-left:${ml}em;text-indent:-1.5em\}\n"
        }
    }
    append css ".bold{font-weight:bold}\n"
    append css ".italic{font-style:italic}\n"
    append css ".bolditalic{font-weight:bold;font-style:italic}\n"
    append css ".ul,.underline{text-decoration:underline}\n"
    append css [string cat ".strike{text-decoration:line-through;" \
            "text-decoration-color:#FF1A1A}\n"]
    append css ".highlight{background-color:$HIGHLIGHT_COLOR}\n"
    append css ".sub{font-size:75%;vertical-align:sub}\n"
    append css ".sup{font-size:75%;vertical-align:super}\n"
    append css [string cat "a.url{text-decoration:underline;" \
            "text-decoration-color:$URL_UL_COLOR;color:inherit}\n"]
    append css [string cat "ste-mark{display:inline-block;width:0;" \
            "height:0;overflow:hidden}\n"]
    dict for {tag hex} $COLOR_FOR_TAG { append css ".$tag\{color:$hex\}\n" }

    set escTitle [my xml_escape $title]
    set out "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n<meta\
        charset=\"utf-8\">\n"
    append out "<title>$escTitle</title>\n<style>\n$css</style>\n</head>\n"
    append out "<body data-title=\"[my xml_escape_attr \
        $title]\">\n$body</body>\n</html>\n"
}
