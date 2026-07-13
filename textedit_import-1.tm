# Copyright © 2025 Mark Summerfield. All rights reserved.

oo::define TextEdit method import_text txt {
    my clear
    $Text insert end $txt
    my after_load 1.0
}

oo::define TextEdit method import_html html {
    my clear
    my from_html $html
    my after_load 1.0
}

oo::define TextEdit method import_xml xml {
    my clear
    my from_xml $xml 
    my after_load 1.0
}
