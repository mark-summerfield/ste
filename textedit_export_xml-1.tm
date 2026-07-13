# Copyright © 2025 Mark Summerfield. All rights reserved.
#
# Adpated from Claude AI-generated code (all comments bar this are from
# the AI).
#
# Converts the text widget's contents into an intermediate XML document
# that's easy to walk when writing exporters (as_html, a future
# as_markdown, etc.) -- see as_xml below.
#
# Why an intermediate format at all: Tk tags are just independent sets of
# character ranges -- they are NOT required to nest (tagon A, tagon B,
# tagoff A, tagoff B is perfectly legal). That makes it impossible in
# general to represent tag ranges as nested XML elements. [$Text dump]
# sidesteps this for us: every time the *set* of tags covering the text
# changes, it emits a fresh `text` event. So each `text` event already
# corresponds to a maximal run with a constant tag-state, and all we have
# to do is track that state as a set and stamp it onto a flat <run>
# element instead of trying to nest elements to match tag lifetimes.
#
# Two kinds of tags are distinguished, based on make_tags:
#   * paragraph-level ("block") tags -- these configure -justify or
#     -lmargin1/-lmargin2, i.e. `center`, `right`, and `bindent<N>` /
#     `tindent<N>` / `nindent<N>` (bullet / plain / numbered indents,
#     levels 0..2). These become attributes of a <para> element. (`left`
#     is a real tag Tk/ntext puts on text, but ste doesn't treat it as
#     meaningful content -- GetTagDicts filters it out and HtmlTagOn has
#     no case for it, so as_xml drops it too.)
#   * everything else is treated as an inline ("run") tag -- bold, italic,
#     bolditalic, ul, underline, strike, highlight, url, sub, sup, and all
#     the named colours (red, blue, ...). These become a space separated
#     `tags` attribute on <run>, using the same tag names HtmlTagOn/
#     HtmlTagOff already switch on.
#
# A new <para> is started every time a newline character is consumed from
# a `text` event, so blank lines become empty <para/> elements and line
# counts round-trip exactly. `mark` events (other than the transient
# built-in `insert`/`current` marks, skipped the same way deserialize
# skips them) are kept in place as empty elements so their position in
# the flow isn't lost.

oo::define TextEdit method as_xml title {
    set tkt [$Text dump -text -mark -tag 1.0 "end -1 char"]
    my XmlFromDump $tkt $title
}

# Pure function of the dump list (plus a title for the root element) --
# kept separate from as_xml so it can be unit tested without a live text
# widget, e.g. against a loaded .tkt file's contents.
oo::define TextEdit classmethod XmlFromDump {tkt title} {
    set inlineTags {}     ;# ordered list of currently-active inline tags
    set justifyStack {}   ;# stack of currently-active justify tags
    set indentStack {}    ;# stack of currently-active indent tags

    # Sets of paragraph-level tags seen active at any point *during the
    # paragraph currently being built* -- a tag that opens and closes
    # entirely within one line (e.g. wrapped tightly around a heading's
    # words rather than spanning to the trailing newline) still needs to
    # count, so we can't rely on the stack alone at newline-time.
    #
    # These are seeded LAZILY (via pendingSeed) rather than immediately
    # when a paragraph is flushed: a level transition like nested indents
    # closing one bindent<N> and opening bindent<N+1> shows up in the
    # dump as `tagoff bindentN X.0 tagon bindentN+1 X.0` -- both sharing
    # the exact index the newline was consumed at. Seeding eagerly at
    # flush time would grab indentStack before that tagoff/tagon pair
    # had been processed, misattributing the new paragraph to the old
    # (about-to-close) level. Deferring the snapshot until the paragraph
    # actually needs it (first real content, or being flushed empty)
    # guarantees any same-index events have already landed.
    set justifySeen {}
    set indentSeen {}
    set pendingSeed 0

    set paraChildren {}   ;# serialized child fragments of current para
    set havePara 0         ;# has *anything* happened since para started?

    set out "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
    append out "<ste title=\"[my xml_escape_attr $title]\">\n"

    foreach {key value index} $tkt {
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
                        if {$p != -1} {
                            set justifyStack [lreplace $justifyStack $p $p]
                        }
                    }
                    indent {
                        set p [lsearch -exact $indentStack $value]
                        if {$p != -1} {
                            set indentStack [lreplace $indentStack $p $p]
                        }
                    }
                    default {
                        set p [lsearch -exact $inlineTags $value]
                        if {$p != -1} {
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
                lappend paraChildren "<mark name=\"[my xml_escape_attr \
                    $value]\" index=\"$index\"/>"
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
                            lappend paraChildren [my XmlMakeRun $remaining \
                                    $inlineTags]
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
                        lappend paraChildren [my XmlMakeRun $chunk \
                                $inlineTags]
                    }
                    # Safety net: a paragraph with no content at all
                    # (blank line) still needs a seed, or a carried-over
                    # indent/justify tag would be lost.
                    if {$pendingSeed} {
                        set justifySeen $justifyStack
                        set indentSeen $indentStack
                        set pendingSeed 0
                    }
                    append out [my XmlMakePara $justifySeen $indentSeen \
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
                # Forward-compatible: preserve anything we don't
                # specifically recognise rather than silently dropping it
                # (e.g. image/window, if ste ever grows that support).
                if {$pendingSeed} {
                    set justifySeen $justifyStack
                    set indentSeen $indentStack
                    set pendingSeed 0
                }
                lappend paraChildren \
                    "<$key value=\"[my xml_escape_attr $value]\" \
                    index=\"$index\"/>"
                set havePara 1
            }
        }
    }

    if {$pendingSeed} {
        set justifySeen $justifyStack
        set indentSeen $indentStack
        set pendingSeed 0
    }
    # Flush a final paragraph if the dump didn't end on a newline.
    if {$havePara} {
        append out [my XmlMakePara $justifySeen $indentSeen $paraChildren]
    }

    append out "</ste>\n"
}

# Classify a tag name: skip, justify, indent, or inline (default).
oo::define TextEdit classmethod XmlClassifyTag tag {
    if {$tag eq "left"} { return skip }
    if {$tag in {center right}} { return justify }
    if {[regexp {^[bnt]indent[0-9]+$} $tag]} { return indent }
    return inline
}

# Build a <run> element (or bare escaped text if no tags are active).
oo::define TextEdit classmethod XmlMakeRun {text tags} {
    if {![llength $tags]} { return "<run>[my xml_escape $text]</run>" }
    return "<run tags=\"[my xml_escape_attr \
        [join $tags { }]]\">[my xml_escape $text]</run>"
}

# Given the set of tags seen active at any point during the current
# paragraph, resolve to a single winner using the given lowest->highest
# priority list (this mirrors Tk's own tag-priority based conflict
# resolution, i.e. creation order in make_tags: center before right).
oo::define TextEdit classmethod XmlResolveTag {seen priority} {
    set winner {} ;# We want to keep overwriting with highest priority
    foreach cand $priority { if {$cand in $seen} { set winner $cand } }
    # Fall back to whatever was seen first if nothing matched the
    # priority list (shouldn't normally happen).
    if {$winner eq {} && [llength $seen]} { set winner [lindex $seen 0] }
    return $winner
}

# Build a <para ...>...</para> (or self-closed <para/> when empty).
# justifySeen/indentSeen are the *sets* of paragraph-level tags that were
# active at any point while this paragraph's content was being emitted.
oo::define TextEdit classmethod XmlMakePara {justifySeen indentSeen \
        paraChildren} {
    const INDENT_KIND [dict create bindent bullet tindent indent \
            nindent number]
    set attrs {}
    set justify [my XmlResolveTag $justifySeen {center right}]
    if {$justify ne {}} {
        lappend attrs "justify=\"[my xml_escape_attr $justify]\""
    }
    # indentSeen may contain tags of more than one kind (bindent/tindent/
    # nindent); pick the winning *kind* first, then use whichever tag of
    # that kind was seen (there should only be one -- levels aren't
    # combined within a single kind on one line).
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
    if {$indentTag ne {}} {
        regexp {^(bindent|tindent|nindent)([0-9]+)$} $indentTag _ kind level
        lappend attrs "indent=\"[dict get $INDENT_KIND $kind]\""
        lappend attrs "level=\"$level\""
    }
    set attrStr [expr {[llength $attrs] ? " [join $attrs { }]" : {}}]
    if {![llength $paraChildren]} {
        return "  <para$attrStr/>\n"
    }
    set body "  <para$attrStr>\n"
    foreach child $paraChildren {
        append body "    $child\n"
    }
    append body "  </para>\n"
}

oo::define TextEdit classmethod xml_escape s {
    string map {& &amp; < &lt; > &gt;} $s
}

oo::define TextEdit classmethod xml_escape_attr s {
    string map {& &amp; < &lt; > &gt; \" &quot;} $s
}
