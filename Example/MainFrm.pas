unit MainFrm;

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

interface

uses
  {$IFDEF MSWINDOWS} Windows, {$ELSE} LCLIntf, {$ENDIF}
  Messages, SysUtils, Variants,
  Classes, Graphics, Controls, Forms, Dialogs,
  {$IFDEF FPC}
  PrintersDlgs,
  {$ENDIF}
  PdfiumCore, ExtCtrls, StdCtrls, PdfiumCtrl, Spin, ComCtrls, BitMapForm;

type

  { TfrmMain }

  TfrmMain = class(TForm)
    btnPrev: TButton;
    btnNext: TButton;
    btnCopy: TButton;
    btnScale: TButton;
    chkLCDOptimize: TCheckBox;
    chkSmoothScroll: TCheckBox;
    edtZoom: TSpinEdit;
    btnPrint: TButton;
    PrintDialog1: TPrintDialog;
    OpenDialog1: TOpenDialog;
    ListViewAttachments: TListView;
    SaveDialog1: TSaveDialog;
    Button1: TButton;
    Button2: TButton;
    procedure FormCreate(Sender: TObject);
    procedure btnPrevClick(Sender: TObject);
    procedure btnNextClick(Sender: TObject);
    procedure btnCopyClick(Sender: TObject);
    procedure btnScaleClick(Sender: TObject);
    procedure chkLCDOptimizeClick(Sender: TObject);
    procedure chkSmoothScrollClick(Sender: TObject);
    procedure edtZoomChange(Sender: TObject);
    procedure btnPrintClick(Sender: TObject);
    procedure ListViewAttachmentsDblClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
  private
    { Private-Deklarationen }
    FCtrl: TPdfControl;
    procedure WebLinkClick(Sender: TObject; Url: string);
    procedure ListAttachments;
  public
    { Public-Deklarationen }
  end;

var
  frmMain: TfrmMain;

implementation

uses
  TypInfo, Printers;

{$IFNDEF FPC}
  {$R *.dfm}
{$ELSE}
  {$R *.lfm}
{$ENDIF}

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  PDFiumDllDir := ExtractFilePath(ParamStr(0));


  FCtrl := TPdfControl.Create(Self);
  FCtrl.Align := alClient;
  FCtrl.Parent := Self;
  FCtrl.SendToBack; // put the control behind the buttons
  FCtrl.Color := clGray;
  //FCtrl.Color := clWhite;
  //FCtrl.PageBorderColor := clBlack;
  //FCtrl.PageShadowColor := clDkGray;
  FCtrl.ScaleMode := smFitWidth;
  FCtrl.PageColor := RGB(255, 255, 200);
  FCtrl.OnWebLinkClick := WebLinkClick;

  edtZoom.Value := FCtrl.ZoomPercentage;

  if FileExists(ParamStr(1)) then
    FCtrl.LoadFromFile(ParamStr(1))
  else if OpenDialog1.Execute then
    FCtrl.LoadFromFile(OpenDialog1.FileName)
  else
  begin
    Application.ShowMainForm := False;
    Application.Terminate;
  end;

  ListAttachments;
end;

procedure TfrmMain.ListAttachments;
var
  I: Integer;
  Att: TPdfAttachment;
  ListItem: TListItem;
begin
  if (FCtrl.Document <> nil) and FCtrl.Document.Active then
  begin
    ListViewAttachments.Visible := FCtrl.Document.Attachments.Count > 0;

    ListViewAttachments.Items.BeginUpdate;
    try
      for I := 0 to FCtrl.Document.Attachments.Count - 1 do
      begin
        Att := FCtrl.Document.Attachments[I];
        ListItem := ListViewAttachments.Items.Add;
        ListItem.Caption := Format('%s (%d Bytes)', [Att.Name, Att.ContentSize]);
      end;
    finally
      ListViewAttachments.Items.EndUpdate;
    end;
  end;
end;

procedure TfrmMain.btnPrevClick(Sender: TObject);
begin
  FCtrl.GotoPrevPage;
end;

procedure TfrmMain.btnNextClick(Sender: TObject);
begin
  FCtrl.GotoNextPage;
end;

procedure TfrmMain.btnCopyClick(Sender: TObject);
begin
  FCtrl.HightlightText('Delphi 2010', False, False);
end;

procedure TfrmMain.btnScaleClick(Sender: TObject);
begin
  if FCtrl.ScaleMode = High(FCtrl.ScaleMode) then
    FCtrl.ScaleMode := Low(FCtrl.ScaleMode)
  else
    FCtrl.ScaleMode := Succ(FCtrl.ScaleMode);
  Caption := GetEnumName(TypeInfo(TPdfControlScaleMode), Ord(FCtrl.ScaleMode));
end;

procedure TfrmMain.Button1Click(Sender: TObject);
var
  s : String;
  obj : TPDFObject;
begin
  showMessage(FCtrl.Document.Pages[0].AllText);
  s := '';
  for obj in FCtrl.Document.Pages[0].Objects do
    s := s + obj.Text+#13#10;
  showMessage(s);
end;

procedure TfrmMain.Button2Click(Sender: TObject);
var
  obj : TPDFObject;
  bmp : TBitmap;
  i : integer;
begin
  ShowMessage('Object count = '+inttostr(FCtrl.Document.Pages[0].Objects.count));
  i := 0;
  for obj in FCtrl.Document.Pages[0].Objects do
  begin
    if (obj.kind = potImage) then
    begin
      ShowMessage('Object index = '+inttostr(i));
      bmp := obj.AsBitmap;
      try
        ShowBitmap(self, bmp);
      finally
        bmp.Free;
      end;
    end;
    inc(i);
  end;
end;

procedure TfrmMain.WebLinkClick(Sender: TObject; Url: string);
begin
  ShowMessage(Url);
end;

procedure TfrmMain.chkLCDOptimizeClick(Sender: TObject);
begin
  if chkLCDOptimize.Checked then
    FCtrl.DrawOptions := FCtrl.DrawOptions + [proLCDOptimized]
  else
    FCtrl.DrawOptions := FCtrl.DrawOptions - [proLCDOptimized];
end;

procedure TfrmMain.chkSmoothScrollClick(Sender: TObject);
begin
  FCtrl.SmoothScroll := chkSmoothScroll.Checked;
end;

procedure TfrmMain.edtZoomChange(Sender: TObject);
begin
  FCtrl.ZoomPercentage := edtZoom.Value;
end;

procedure TfrmMain.btnPrintClick(Sender: TObject);
{var
  PdfPrinter: TPdfDocumentPrinter;}
begin
 // TPdfDocumentVclPrinter.PrintDocument(FCtrl.Document, 'PDF Example Print Job');

{  PrintDialog1.MinPage := 1;
  PrintDialog1.MaxPage := FCtrl.Document.PageCount;

  if PrintDialog1.Execute(Handle) then
  begin
    PdfPrinter := TPdfDocumentVclPrinter.Create;
    try
      //PdfPrinter.PrintTextWithGDI := True;
      //PdfPrinter.FitPageToPrintArea := False;

      if PrintDialog1.PrintRange = prAllPages then
        PdfPrinter.Print(FCtrl.Document)
      else
        PdfPrinter.Print(FCtrl.Document, PrintDialog1.FromPage - 1, PrintDialog1.ToPage - 1); // zero-based PageIndex
    finally
      PdfPrinter.Free;
    end;
  end;}
end;

procedure TfrmMain.ListViewAttachmentsDblClick(Sender: TObject);
var
  Att: TPdfAttachment;
begin
  if ListViewAttachments.Selected <> nil then
  begin
    Att := FCtrl.Document.Attachments[ListViewAttachments.Selected.Index];
    SaveDialog1.FileName := Att.Name;
    if SaveDialog1.Execute then
      Att.SaveToFile(SaveDialog1.FileName);
  end;
end;

end.
