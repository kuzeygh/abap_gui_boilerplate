class lcl_page_hoc definition final.
  public section.
    interfaces zif_abapgit_gui_page.

    class-methods wrap
      importing
        iv_page_title type string
        ii_child      type ref to zif_abapgit_gui_page
      returning
        value(ro_page) type ref to lcl_page_hoc.

  private section.
    data mv_page_title type string.
    data mi_child type ref to zif_abapgit_gui_page.
endclass.

class lcl_page_hoc implementation.

  method zif_abapgit_gui_page~render.

    create object ro_html.
    ro_html->add( '<!DOCTYPE html>' ).                      "#EC NOTEXT
    ro_html->add( '<html>' ).                               "#EC NOTEXT

    ro_html->add( '<head>' ).                               "#EC NOTEXT

    ro_html->add( '<meta http-equiv="content-type" content="text/html; charset=utf-8">' ). "#EC NOTEXT
    ro_html->add( '<meta http-equiv="X-UA-Compatible" content="IE=11,10,9,8" />' ). "#EC NOTEXT
    ro_html->add( |<title>{ mv_page_title }</title>| ).               "#EC NOTEXT
*    ro_html->add( '<link rel="stylesheet" type="text/css" href="css/common.css">' ).
*    ro_html->add( '<script type="text/javascript" src="js/common.js"></script>' ). "#EC NOTEXT
    ro_html->add( '</head>' ).                              "#EC NOTEXT

    ro_html->add( '<body>' ).                               "#EC NOTEXT
    ro_html->add( '<div id="root">' ).                    "#EC NOTEXT
    ro_html->add( mi_child->render( ) ).
    ro_html->add( '</div>' ).                               "#EC NOTEXT
    ro_html->add( '</body>' ).                              "#EC NOTEXT

* TODO render after_body, html or component ???

    ro_html->add( '</html>' ).                              "#EC NOTEXT

  endmethod.

  method zif_abapgit_gui_page~on_event.

    mi_child->on_event(
      EXPORTING
        iv_action    = iv_action
        iv_prev_page = iv_prev_page
        iv_getdata   = iv_getdata
        it_postdata  = it_postdata
      IMPORTING
        ei_page      = ei_page
        ev_state     = ev_state ).

  endmethod.

  method wrap.

    create object ro_page.
    ro_page->mv_page_title = iv_page_title.
    ro_page->mi_child = ii_child.

  endmethod.

endclass.

class lcl_gui definition final.
  public section.
    class-methods run_gui
      importing
        ii_router    type ref to zif_abapgit_gui_router
        ii_asset_man type ref to zif_abapgit_gui_asset_manager
      raising
        zcx_abapgit_exception.
endclass.

class lcl_gui implementation.
  method run_gui.
    data lo_gui type ref to zcl_abapgit_gui.

    create object lo_gui
      exporting
        ii_router    = ii_router
        ii_asset_man = ii_asset_man.
    lo_gui->go_home( ).

    call selection-screen 1001. " trigger screen
  endmethod.
endclass.

class lcl_asset_manager definition final.

  public section.

    interfaces zif_abapgit_gui_asset_manager.

    types:
      begin of ty_asset_entry.
        include type zif_abapgit_gui_asset_manager~ty_web_asset.
        types:  mime_name type wwwdatatab-objid,
      end of ty_asset_entry,
      tt_asset_register type standard table of ty_asset_entry with default key.

    methods register_asset
      importing
        iv_url       type string
        iv_type      type string
        iv_mime_name type wwwdatatab-objid optional
        iv_base64    type string optional
        iv_inline    type string optional.

  private section.

    data mt_asset_register type tt_asset_register.

    methods get_mime_asset
      importing
        iv_mime_name    type c
      returning
        value(rv_xdata) type xstring
      raising
        zcx_abapgit_exception.

ENDCLASS.


class lcl_asset_manager implementation.

  method get_mime_asset.

    data: ls_key    type wwwdatatab,
          lv_size_c type wwwparams-value,
          lv_size   type i,
          lt_w3mime type standard table of w3mime.

    ls_key-relid = 'MI'.
    ls_key-objid = iv_mime_name.

    " get exact file size
    call function 'WWWPARAMS_READ'
      exporting
        relid            = ls_key-relid
        objid            = ls_key-objid
        name             = 'filesize'
      importing
        value            = lv_size_c
      exceptions
        entry_not_exists = 1.

    if sy-subrc is not initial.
      return.
    endif.

    lv_size = lv_size_c.

    " get binary data
    call function 'WWWDATA_IMPORT'
      exporting
        key               = ls_key
      tables
        mime              = lt_w3mime
      exceptions
        wrong_object_type = 1
        import_error      = 2.

    if sy-subrc is not initial.
      return.
    endif.

    rv_xdata = zcl_abapgit_string_utils=>bintab_to_xstring(
      iv_size   = lv_size
      it_bintab = lt_w3mime ).

  endmethod.

  method register_asset.

    data ls_asset like line of mt_asset_register.

    split iv_type at '/' into ls_asset-type ls_asset-subtype.
    ls_asset-url       = iv_url.
    ls_asset-mime_name = iv_mime_name.
    if iv_base64 is not initial.
      ls_asset-content = zcl_abapgit_string_utils=>base64_to_xstring( iv_base64 ).
    elseif iv_inline is not initial.
      ls_asset-content = zcl_abapgit_string_utils=>string_to_xstring( iv_inline ).
    endif.

    append ls_asset to mt_asset_register.

  endmethod.

  method zif_abapgit_gui_asset_manager~get_all_assets.

    field-symbols <a> like line of mt_asset_register.
    field-symbols <web_asset> like line of rt_assets.

    loop at mt_asset_register assigning <a>.
      append initial line to rt_assets assigning <web_asset>.
      move-corresponding <a> to <web_asset>.
      if <web_asset>-content is initial. " inline content has the priority
        <web_asset>-content = get_mime_asset( <a>-mime_name ).
      endif.
      if <web_asset>-content is initial.
        zcx_abapgit_exception=>raise( |failed to load GUI asset: { <a>-url }| ).
      endif.
    endloop.

  endmethod.
endclass.