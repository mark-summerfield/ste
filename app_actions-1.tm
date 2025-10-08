# Copyright © 2025 Mark Summerfield. All rights reserved.

package require about_form
package require config
package require config_form
package require ins_char_form
package require ref
package require textedit

oo::define App method on_file_new {} {
    my on_file_save
    set Filename ""
    set textEdit [$TheTextEdit textedit]
    $textEdit delete 1.0 end
    $textEdit edit modified false
    $textEdit edit reset
    focus $textEdit
}

oo::define App method on_file_open {} {
    my on_file_save
    set dir [expr {$Filename eq "" ? [file home] \
                                   : [file dirname $Filename]}]
    set filename [tk_getOpenFile -initialdir $dir -filetypes $::STE_FILES \
            -title "[tk appname] — Open" -parent .]
    if {$filename ne ""} {
        set Filename $filename
        my file_open
    }
}

oo::define App method on_file_save {} {
    if {$Filename ne ""} {
        my file_save
    } else {
        my on_file_save_as
    }
}

oo::define App method on_file_save_as {} {
    set dir [expr {$Filename eq "" ? [file home] \
                                   : [file dirname $Filename]}]
    set filename [tk_getSaveFile -initialdir $dir -filetypes $::STE_FILES \
            -title "[tk appname] — Save As" -parent .]
    if {$filename ne ""} {
        set Filename $filename
        my file_save
    }
}

oo::define App method on_file_export_html {} {
    if {$Filename eq ""} { my save_as }
    set filename [regsub {\.ste$} $Filename .html]
    writeFile $filename [$TheTextEdit as_html $filename]
    my show_message "Exported '$filename'"
}

oo::define App method on_file_export_text {} {
    if {$Filename eq ""} { my save_as }
    set filename [regsub {\.ste$} $Filename .txt]
    writeFile $filename [$TheTextEdit as_text]
    my show_message "Exported '$filename'"
}

oo::define App method on_file_print {} {
    if {[catch {tk print [$TheTextEdit textedit]} err]} {
        my show_error $err
    }
}

oo::define App method on_config {} {
    set config [Config new]
    set ok [Ref new false]
    set family [$config family]
    set size [$config size]
    set form [ConfigForm new $ok]
    tkwait window [$form form]
    if {[$ok get]} {
        if {$family ne [$config family] || $size != [$config size]} {
            $TheTextEdit make_fonts [$config family] [$config size]
        }
    }
}

oo::define App method on_about {} {
    AboutForm new "Styled Text Editor" \
        https://github.com/mark-summerfield/ste
}

oo::define App method on_quit {} {
    if {[[$TheTextEdit textedit] edit modified]} { my on_file_save }
    set config [Config new]
    $config save $Filename
    exit
}

oo::define App method on_edit_undo {} {
    set textEdit [$TheTextEdit textedit]
    if {[$textEdit edit canundo]} { $textEdit edit undo }
}

oo::define App method on_edit_redo {} {
    set textEdit [$TheTextEdit textedit]
    if {[$textEdit edit canredo]} { $textEdit edit redo }
}

oo::define App method on_edit_copy {} {
    tk_textCopy [$TheTextEdit textedit]
}

oo::define App method on_edit_cut {} { tk_textCut [$TheTextEdit textedit] }

oo::define App method on_edit_paste {} {
    tk_textPaste [$TheTextEdit textedit]
}

oo::define App method on_edit_ins_char {} {
    set ch [InsCharForm show]
    if {$ch ne ""} { [$TheTextEdit textedit] insert insert $ch }
}

oo::define App method file_open {} {
    $TheTextEdit deserialize [readFile $Filename binary]
    set textEdit [$TheTextEdit textedit]
    $textEdit edit modified false
    $textEdit edit reset
    $textEdit mark set insert end
    $textEdit see insert
    focus $textEdit
    wm title . "[tk appname] — [file tail $Filename]"
    my show_message "Opened '$Filename'."
}

oo::define App method file_save {} {
    writeFile $Filename binary [$TheTextEdit serialize]
    my show_message "Saved '$Filename'."
}
