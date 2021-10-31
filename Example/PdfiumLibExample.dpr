program PdfiumLibExample;

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

uses
  Forms,
  {$IFDEF FPC}
  Interfaces,
  {$ENDIF }
  MainFrm in 'MainFrm.pas' {frmMain},
  PdfiumCore in '..\Source\PdfiumCore.pas',
  PdfiumCtrl in '..\Source\PdfiumCtrl.pas',
  PdfiumLib in '..\Source\PdfiumLib.pas',
  BitMapForm in 'BitMapForm.pas' {BitmapDialog};

{.$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
