unit BitMapForm;

interface

uses
  Messages, SysUtils, Classes, Graphics,
  Controls, Forms, Dialogs, StdCtrls, ExtCtrls;

type
  TBitmapDialog = class(TForm)
    Image1: TImage;
    Panel1: TPanel;
    Button1: TButton;
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  BitmapDialog: TBitmapDialog;

procedure ShowBitmap(owner : TComponent; bmp : TBitMap);

implementation

{$IFNDEF FPC}
  {$R *.dfm}
{$ELSE}
  {$R *.lfm}
{$ENDIF}


procedure ShowBitmap(owner : TComponent; bmp : TBitMap);
var
  dlg: TBitmapDialog;
begin
  dlg := TBitmapDialog.Create(owner);
  try
    dlg.Image1.Picture.Assign(bmp);
    dlg.ShowModal;
  finally
    dlg.Free;
  end;
end;

end.
