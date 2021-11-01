object BitmapDialog: TBitmapDialog
  Left = 0
  Top = 0
  Caption = 'Bitmap'
  ClientHeight = 423
  ClientWidth = 555
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 13
  object Image1: TImage
    Left = 0
    Top = 0
    Width = 555
    Height = 382
    Align = alClient
    Proportional = True
    Stretch = True
    ExplicitTop = 2
  end
  object Panel1: TPanel
    Left = 0
    Top = 382
    Width = 555
    Height = 41
    Align = alBottom
    TabOrder = 0
    object Button1: TButton
      Left = 472
      Top = 8
      Width = 75
      Height = 25
      Caption = 'OK'
      Default = True
      ModalResult = 1
      TabOrder = 0
    end
  end
end
