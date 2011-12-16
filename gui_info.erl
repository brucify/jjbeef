-module(gui_info).
-compile(export_all).
-include_lib("wx/include/wx.hrl").

start(Parents) ->
 new_mini_frame(Parents).


new_mini_frame(Parents) ->
    MiniFrame = wxMiniFrame:new(Parents, 1, "About Gl�gg", [{style, ?wxDEFAULT_FRAME_STYLE bor ?wxFRAME_FLOAT_ON_PARENT}]),
 %%   wxMiniFrame:setSize(MiniFrame, {200, 200}),
    Panel = wxPanel:new(MiniFrame, []),
    wxWindow:setBackgroundColour(Panel, ?wxWHITE),
    Text1 = "JJBEEF DEVELOPMENT TEAM.\n",
    Text2 = "Project Manager: Jing Liu \n GUI Designer: Jody Swartz\n",
    Text3 = "Software Architect: Bruce \n Quality Manager: Eva-Lisa Kedborn\n",
    Text4 = "Designer: Fredrik Gustafsson \n Version: 3.0 \n \n Powered by:",
    IText = Text1 ++ Text2 ++ Text3 ++ Text4,
    
    InfoText = wxStaticText:new(Panel, ?wxID_ANY, IText, [{style, ?wxALIGN_CENTER}]),

   %%JJBEEF Logo 
   Image_JLogo = wxImage:new("jjbeef.jpg", [{type, ?wxBITMAP_TYPE_JPEG}]),
   Bitmap_JLogo = wxBitmap:new(Image_JLogo, []),
   StaticBitmap_JLogo  = wxStaticBitmap:new(Panel, 2, Bitmap_JLogo),
   
  %%Glogg Logo 
   Image_Logo = wxImage:new("glogg.png", [{type, ?wxBITMAP_TYPE_PNG}]),
   Bitmap_Logo = wxBitmap:new(Image_Logo, []),
   StaticBitmap_Logo  = wxStaticBitmap:new(Panel, 2, Bitmap_Logo),
    OutSizer = wxBoxSizer:new(?wxVERTICAL),    
    MiniFSizer = wxGridSizer:new(3, 1, 1, 1),
 wxSizer:add(OutSizer, MiniFSizer, [{proportion, 0}, {flag, ?wxEXPAND}]),
    wxSizer:add(MiniFSizer, StaticBitmap_Logo, [{proportion, 0}, {flag, ?wxALIGN_CENTER}]),
     wxSizer:add(MiniFSizer, InfoText,  [{proportion, 0}, {flag, ?wxALIGN_CENTER}]),
      
     wxSizer:add(MiniFSizer, StaticBitmap_JLogo, [{proportion, 0}, {flag, ?wxALIGN_CENTER}]),
   
    wxPanel:setSizer(Panel, OutSizer), 
    wxMiniFrame:center(MiniFrame),
    wxMiniFrame:show(MiniFrame). 



