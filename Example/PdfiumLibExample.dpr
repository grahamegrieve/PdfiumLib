program PdfiumLibExample;

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

uses
  Forms, Interfaces,
  MainFrm in 'MainFrm.pas' {frmMain},
  PdfiumCore in '..\Source\PdfiumCore.pas',
  PdfiumCtrl in '..\Source\PdfiumCtrl.pas',
  PdfiumLib in '..\Source\PdfiumLib.pas';

{.$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
