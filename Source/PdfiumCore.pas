{$IFDEF FPC}
{$MODE DELPHI}
{$ENDIF}

{$A8,B-,E-,F-,G+,H+,I+,J-,K-,M-,N-,P+,Q-,R-,S-,T-,U-,V+,X+,Z1}
{$STRINGCHECKS OFF}

{$IFDEF MSWINDOWS}
  { On Windows, don't use FPDF_LoadDocument because it is limited to ANSI file names and dloOnDemand emulates it }
  {$DEFINE DELAYED_LOAD} { but this is done as define for testing}

  { On windows, can use faster windows onlt rendering supported by PDFium }
  {$DEFINE WINDOWS_RENDER} { but this is done as define for testing}
{$ENDIF}

{$DEFINE NON_DC_DRAWING}

{
Only implemented properly on windows:
* Timers for filling out forms
* printing
}

unit PdfiumCore;

interface

uses
  {$IFDEF MSWINDOWS}Windows, WinSpool, {$ENDIF}
  Types, SysUtils, Classes, Contnrs, PdfiumLib, Graphics
  {$IFDEF FPC} {$IFNDEF WINDOWS}, LCLType, LclIntf {$ENDIF} {$ENDIF};

const
  // DIN A4
  PdfDefaultPageWidth = 595;
  PdfDefaultPageHeight = 842;

type
  EPdfException = class(Exception);
  EPdfUnsupportedFeatureException = class(EPdfException);
  EPdfArgumentOutOfRange = class(EPdfException);

  TPdfUnsupportedFeatureHandler = procedure(nType: Integer; const Typ: string) of object;

  TPdfDocument = class;
  TPdfPage = class;
  TPdfAttachmentList = class;

  TPdfPoint = record
    X, Y: Double;
    procedure Offset(XOffset, YOffset: Double);
    class function Empty: TPdfPoint; static;
  end;

  TPdfRect = record
  private
    function GetHeight: Double; inline;
    function GetWidth: Double; inline;
    procedure SetHeight(const Value: Double); inline;
    procedure SetWidth(const Value: Double); inline;
  public
    property Width: Double read GetWidth write SetWidth;
    property Height: Double read GetHeight write SetHeight;
    procedure Offset(XOffset, YOffset: Double);

    class function Empty: TPdfRect; static;
  public
    case Integer of
      0: (Left, Top, Right, Bottom: Double);
      1: (TopLeft: TPdfPoint; BottomRight: TPdfPoint);
  end;

  TPdfRectArray = array of TPdfRect;

  TPdfDocumentCustomReadProc = function(Param: Pointer; Position: LongWord; Buffer: PByte; Size: LongWord): Boolean;

  TPdfPageRenderOptionType = (
    proAnnotations,            // Set if annotations are to be rendered.
    proLCDOptimized,           // Set if using text rendering optimized for LCD display.
    proNoNativeText,           // Don't use the native text output available on some platforms
    proNoCatch,                // Set if you don't want to catch exception.
    proLimitedImageCacheSize,  // Limit image cache size.
    proForceHalftone,          // Always use halftone for image stretching.
    proPrinting,               // Render for printing.
    proReverseByteOrder        // Set whether render in a reverse Byte order, this flag only enable when render to a bitmap.
  );
  TPdfPageRenderOptions = set of TPdfPageRenderOptionType;

  TPdfPageRotation = (
    prNormal             = 0,
    pr90Clockwise        = 1,
    pr180                = 2,
    pr90CounterClockwide = 3
  );

  TPdfDocumentSaveOption = (
    dsoIncremental    = 1,
    dsoNoIncremental  = 2,
    dsoRemoveSecurity = 3
  );

  TPdfDocumentLoadOption = (
    dloMemory,   // load the whole file into memory
    dloMMF,      // load the file by using a memory mapped file (file stays open)
    dloOnDemand  // load the file using the custom load function (file stays open)
  );

  TPdfDocumentPageMode = (
    dpmUnknown        = -1, // Unknown value
    dpmUseNone        = 0,  // Neither document outline nor thumbnail images visible
    dpmUseOutlines    = 1,  // Document outline visible
    dpmUseThumbs      = 2,  // Thumbnial images visible
    dpmFullScreen     = 3,  // Full-screen mode, with no menu bar, window controls, or any other window visible
    dpmUseOC          = 4,  // Optional content group panel visible
    dpmUseAttachments = 5   // Attachments panel visible
  );

  TPdfPrintMode = (
    pmEMF                          = FPDF_PRINTMODE_EMF,
    pmTextMode                     = FPDF_PRINTMODE_TEXTONLY,
    pmPostScript2                  = FPDF_PRINTMODE_POSTSCRIPT2,
    pmPostScript3                  = FPDF_PRINTMODE_POSTSCRIPT3,
    pmPostScriptPassThrough2       = FPDF_PRINTMODE_POSTSCRIPT2_PASSTHROUGH,
    pmPostScriptPassThrough3       = FPDF_PRINTMODE_POSTSCRIPT3_PASSTHROUGH,
    pmEMFImageMasks                = FPDF_PRINTMODE_EMF_IMAGE_MASKS,
    pmPostScript3Type42            = FPDF_PRINTMODE_POSTSCRIPT3_TYPE42,
    pmPostScript3Type42PassThrough = FPDF_PRINTMODE_POSTSCRIPT3_TYPE42_PASSTHROUGH
  );

  TPdfFileIdType = (
    pfiPermanent = 0,
    pfiChanging = 1
  );

  TPdfBitmapFormat = (
    bfGrays = FPDFBitmap_Gray, // Gray scale bitmap, one byte per pixel.
    bfBGR   = FPDFBitmap_BGR,  // 3 bytes per pixel, byte order: blue, green, red.
    bfBGRx  = FPDFBitmap_BGRx, // 4 bytes per pixel, byte order: blue, green, red, unused.
    bfBGRA  = FPDFBitmap_BGRA  // 4 bytes per pixel, byte order: blue, green, red, alpha.
  );

  TPdfFormFieldType = (
    fftUnknown,
    fftPushButton,
    fftCheckBox,
    fftRadioButton,
    fftComboBox,
    fftListBox,
    fftTextField,
    fftSignature
  );

  TPdfObjectType = (
    otUnknown = FPDF_OBJECT_UNKNOWN,
    otBoolean = FPDF_OBJECT_BOOLEAN,
    otNumber = FPDF_OBJECT_NUMBER,
    otString = FPDF_OBJECT_STRING,
    otName = FPDF_OBJECT_NAME,
    otArray = FPDF_OBJECT_ARRAY,
    otDictinary = FPDF_OBJECT_DICTIONARY,
    otStream = FPDF_OBJECT_STREAM,
    otNullObj = FPDF_OBJECT_NULLOBJ,
    otReference = FPDF_OBJECT_REFERENCE
  );

  _TPdfBitmapHideCtor = class(TObject)
  private
    procedure Create;
  end;

  { TPdfBitmap }

  TPdfBitmap = class(_TPdfBitmapHideCtor)
  private
    FBitmap: FPDF_BITMAP;
    FOwnsBitmap: Boolean;
    FWidth: Integer;
    FHeight: Integer;
    FBytesPerScanLine: Integer;
  public
    constructor Create(ABitmap: FPDF_BITMAP; AOwnsBitmap: Boolean = False); overload;
    constructor Create(AWidth, AHeight: Integer; AAlpha: Boolean); overload;
    constructor Create(AWidth, AHeight: Integer; AFormat: TPdfBitmapFormat); overload;
    constructor Create(AWidth, AHeight: Integer; AFormat: TPdfBitmapFormat; ABuffer: Pointer; ABytesPerScanline: Integer); overload;
    destructor Destroy; override;

    procedure FillRect(ALeft, ATop, AWidth, AHeight: Integer; AColor: FPDF_DWORD);
    function GetBuffer: Pointer;

    property Width: Integer read FWidth;
    property Height: Integer read FHeight;
    property BytesPerScanline: Integer read FBytesPerScanLine;
    property Bitmap: FPDF_BITMAP read FBitmap;

    function toBitmap : TBitmap; overload;
    procedure toBitmap(bmp : TBitmap); overload;
  end;

  PPdfFormFillHandler = ^TPdfFormFillHandler;
  TPdfFormFillHandler = record
    FormFillInfo: FPDF_FORMFILLINFO;
    Document: TPdfDocument;
  end;

  { TPDFObject }
  TPdfObjectKind = (potUnknown, potText, potPath, potImage, potShading, potForm);

  TPDFObject = class (TObject)
  private
    FHandle : FPDF_PAGEOBJECT;
    FTextHandle: FPDF_TEXTPAGE;
    function GetKind: TPdfObjectKind;
    function GetText: String;
  public
    constructor Create(Handle : FPDF_PAGEOBJECT; TextHandle: FPDF_TEXTPAGE);

    property kind : TPdfObjectKind read GetKind;
    property Text : String read GetText;

    function AsBitmap : TBitmap;
  end;

  { TPdfPage }

  TPdfPage = class(TObject)
  private
    FDocument: TPdfDocument;
    FPage: FPDF_PAGE;
    FWidth: Single;
    FHeight: Single;
    FTransparency: Boolean;
    FRotation: TPdfPageRotation;
    FTextHandle: FPDF_TEXTPAGE;
    FSearchHandle: FPDF_SCHHANDLE;
    FLinkHandle: FPDF_PAGELINK;
    FObjects : TObjectList{<TPDFObject>};

    constructor Create(ADocument: TPdfDocument; APage: FPDF_PAGE);
    procedure UpdateMetrics;
    procedure Open;
    procedure SetRotation(const Value: TPdfPageRotation);
    function BeginText: Boolean;
    function BeginWebLinks: Boolean;
    class function GetDrawFlags(const Options: TPdfPageRenderOptions): Integer; static;
    procedure AfterOpen;
    function IsValidForm: Boolean;
    function GetMouseModifier(const Shift: TShiftState): Integer;
    function GetKeyModifier(KeyData: LPARAM): Integer;
    function GetHandle: FPDF_PAGE;
  public
    destructor Destroy; override;
    procedure Close;
    function IsLoaded: Boolean;

    procedure Draw(bitmap : TBitmap; Rotate: TPdfPageRotation = prNormal; const Options: TPdfPageRenderOptions = []); overload;
    procedure Draw(DC: HDC; X, Y, Width, Height: Integer; Rotate: TPdfPageRotation = prNormal; const Options: TPdfPageRenderOptions = []); overload;
    procedure DrawToPdfBitmap(APdfBitmap: TPdfBitmap; X, Y, Width, Height: Integer; Rotate: TPdfPageRotation = prNormal; const Options: TPdfPageRenderOptions = []);
    procedure DrawFormToPdfBitmap(APdfBitmap: TPdfBitmap; X, Y, Width, Height: Integer; Rotate: TPdfPageRotation = prNormal; const Options: TPdfPageRenderOptions = []);

    function DeviceToPage(X, Y, Width, Height: Integer; DeviceX, DeviceY: Integer; Rotate: TPdfPageRotation = prNormal): TPdfPoint; overload;
    function PageToDevice(X, Y, Width, Height: Integer; PageX, PageY: Double; Rotate: TPdfPageRotation = prNormal): TPoint; overload;
    function DeviceToPage(X, Y, Width, Height: Integer; const R: TRect; Rotate: TPdfPageRotation = prNormal): TPdfRect; overload;
    function PageToDevice(X, Y, Width, Height: Integer; const R: TPdfRect; Rotate: TPdfPageRotation = prNormal): TRect; overload;

    procedure ApplyChanges;

    function FormEventFocus(const Shift: TShiftState; PageX, PageY: Double): Boolean;
    function FormEventMouseWheel(const Shift: TShiftState; WheelDelta: Integer; PageX, PageY: Double): Boolean;
    function FormEventMouseMove(const Shift: TShiftState; PageX, PageY: Double): Boolean;
    function FormEventLButtonDown(const Shift: TShiftState; PageX, PageY: Double): Boolean;
    function FormEventLButtonUp(const Shift: TShiftState; PageX, PageY: Double): Boolean;
    function FormEventRButtonDown(const Shift: TShiftState; PageX, PageY: Double): Boolean;
    function FormEventRButtonUp(const Shift: TShiftState; PageX, PageY: Double): Boolean;
    function FormEventKeyDown(KeyCode: Word; KeyData: LPARAM): Boolean;
    function FormEventKeyUp(KeyCode: Word; KeyData: LPARAM): Boolean;
    function FormEventKeyPress(Key: Word; KeyData: LPARAM): Boolean;
    function FormEventKillFocus: Boolean;
    function FormGetFocusedText: string;
    function FormGetSelectedText: string;
    function FormReplaceSelection(const ANewText: string): Boolean;
    function FormSelectAllText: Boolean;
    function FormCanUndo: Boolean;
    function FormCanRedo: Boolean;
    function FormUndo: Boolean;
    function FormRedo: Boolean;

    function BeginFind(const SearchString: WideString; MatchCase, MatchWholeWord: Boolean; FromEnd: Boolean): Boolean;
    function FindNext(var CharIndex, Count: Integer): Boolean;
    function FindPrev(var CharIndex, Count: Integer): Boolean;
    procedure EndFind;

    function GetCharCount: Integer;
    function ReadChar(CharIndex: Integer): WideChar;
    function GetCharFontSize(CharIndex: Integer): Double;
    function GetCharBox(CharIndex: Integer): TPdfRect;
    function GetCharIndexAt(PageX, PageY, ToleranceX, ToleranceY: Double): Integer;
    function AllText : String;
    function ReadText(CharIndex, Count: Integer): string;
    function GetTextAt(const R: TPdfRect): string; overload;
    function GetTextAt(Left, Top, Right, Bottom: Double): WideString; overload;

    function GetTextRectCount(CharIndex, Count: Integer): Integer;
    function GetTextRect(RectIndex: Integer): TPdfRect;

    function HasFormFieldAtPoint(X, Y: Double): TPdfFormFieldType;

    function GetWebLinkCount: Integer;
    function GetWebLinkURL(LinkIndex: Integer): WideString;
    function GetWebLinkRectCount(LinkIndex: Integer): Integer;
    function GetWebLinkRect(LinkIndex, RectIndex: Integer): TPdfRect;

    property Handle: FPDF_PAGE read GetHandle;
    property Width: Single read FWidth;
    property Height: Single read FHeight;
    property Transparency: Boolean read FTransparency;
    property Rotation: TPdfPageRotation read FRotation write SetRotation;
    property Objects : TObjectList read FObjects;
  end;

  TPdfFormInvalidateEvent = procedure(Document: TPdfDocument; Page: TPdfPage; const PageRect: TPdfRect) of object;
  TPdfFormOutputSelectedRectEvent = procedure(Document: TPdfDocument; Page: TPdfPage; const PageRect: TPdfRect) of object;
  TPdfFormGetCurrentPageEvent = procedure(Document: TPdfDocument; var CurrentPage: TPdfPage) of object;
  TPdfFormFieldFocusEvent = procedure(Document: TPdfDocument; Value: PWideChar; ValueLen: Integer; FieldFocused: Boolean) of object;

  TPdfAttachment = record
  private
    FDocument: TPdfDocument;
    FHandle: FPDF_ATTACHMENT;
    procedure CheckValid;

    function GetName: string;
    function GetKeyValue(const Key: string): string;
    procedure SetKeyValue(const Key, Value: string);
    function GetContentSize: Integer;
  public
    // SetContent/LoadFromXxx clears the Values[] dictionary.
    procedure SetContent(const ABytes: TBytes); overload;
    procedure SetContent(const ABytes: TBytes; Index: NativeInt; Count: Integer); overload;
    procedure SetContent(ABytes: PByte; Count: Integer); overload;
    procedure SetContent(const Value: RawByteString); overload;
    procedure SetContent(const Value: string; Encoding: TEncoding = nil); overload; // Default-encoding is UTF-8
    procedure LoadFromStream(Stream: TStream);
    procedure LoadFromFile(const FileName: string);

    procedure GetContent(var ABytes: TBytes); overload;
    procedure GetContent(Buffer: PByte); overload; // use ContentSize to allocate enough memory
    procedure GetContent(var Value: RawByteString); overload;
    procedure GetContent(var Value: WideString; Encoding: TEncoding = nil); overload;
    function GetContentAsBytes: TBytes;
    function GetContentAsRawByteString: RawByteString;
    function GetContentAsString(Encoding: TEncoding = nil): WideString; // Default-encoding is UTF-8

    procedure SaveToStream(Stream: TStream);
    procedure SaveToFile(const FileName: string);

    function HasContent: Boolean;

    function HasKey(const Key: string): Boolean;
    function GetValueType(const Key: string): TPdfObjectType;

    property Name: string read GetName;
    property Values[const Key: string]: string read GetKeyValue write SetKeyValue;
    property ContentSize: Integer read GetContentSize;

    property Handle: FPDF_ATTACHMENT read FHandle;
  end;

  TPdfAttachmentList = class(TObject)
  private
    FDocument: TPdfDocument;
    function GetCount: Integer;
    function GetItem(Index: Integer): TPdfAttachment;
  public
    constructor Create(ADocument: TPdfDocument);

    function Add(const Name: string): TPdfAttachment;
    procedure Delete(Index: Integer);

    property Count: Integer read GetCount;
    property Items[Index: Integer]: TPdfAttachment read GetItem; default;
  end;

  TPdfDocument = class(TObject)
  private type
    PCustomLoadDataRec = ^TCustomLoadDataRec;
    TCustomLoadDataRec = record
      Param: Pointer;
      GetBlock: TPdfDocumentCustomReadProc;
      FileAccess: TFPDFFileAccess;
    end;
  private
    FDocument: FPDF_DOCUMENT;
    FPages: TObjectList;
    FAttachments: TPdfAttachmentList;
    FFileName: string;
    {$IFDEF DELAYED_LOAD}
    FFileHandle: THandle;
    FFileMapping: THandle;
    FBuffer: PByte;
    FBytes: TBytes;
    {$ENDIF}
    FClosing: Boolean;
    FUnsupportedFeatures: Boolean;
    FCustomLoadData: PCustomLoadDataRec;

    FForm: FPDF_FORMHANDLE;
    FFormFillHandler: TPdfFormFillHandler;
    FFormFieldHighlightColor: TColor;
    FFormFieldHighlightAlpha: Integer;
    FPrintHidesFormFieldHighlight: Boolean;
    FFormModified: Boolean;
    FOnFormInvalidate: TPdfFormInvalidateEvent;
    FOnFormOutputSelectedRect: TPdfFormOutputSelectedRectEvent;
    FOnFormGetCurrentPage: TPdfFormGetCurrentPageEvent;
    FOnFormFieldFocus: TPdfFormFieldFocusEvent;

    procedure InternLoadFromMem(Buffer: PByte; Size: NativeInt; const APassword: AnsiString);
    procedure InternLoadFromCustom(ReadFunc: TPdfDocumentCustomReadProc; ASize: LongWord;
      AParam: Pointer; const APassword: AnsiString);
    function InternImportPages(Source: TPdfDocument; PageIndices: PInteger; PageIndicesCount: Integer;
      const Range: AnsiString; Index: Integer; ImportByRange: Boolean): Boolean;
    function GetPage(Index: Integer): TPdfPage;
    function GetPageCount: Integer;
    procedure ExtractPage(APage: TPdfPage);
    function ReloadPage(APage: TPdfPage): FPDF_PAGE;
    function GetPrintScaling: Boolean;
    function GetActive: Boolean;
    procedure CheckActive;
    function GetSecurityHandlerRevision: Integer;
    function GetDocPermissions: Integer;
    function GetFileVersion: Integer;
    function GetPageSize(Index: Integer): TPdfPoint;
    function GetPageMode: TPdfDocumentPageMode;
    function GetNumCopies: Integer;
    procedure DocumentLoaded;
    procedure SetFormFieldHighlightAlpha(Value: Integer);
    procedure SetFormFieldHighlightColor(const Value: TColor);
    function FindPage(Page: FPDF_PAGE): TPdfPage;
    procedure UpdateFormFieldHighlight;
  public
    constructor Create;
    destructor Destroy; override;

    procedure LoadFromCustom(ReadFunc: TPdfDocumentCustomReadProc; ASize: LongWord; AParam: Pointer; const APassword: AnsiString = '');
    procedure LoadFromActiveStream(Stream: TStream; const APassword: AnsiString = ''); // Stream must not be released until the document is closed
    procedure LoadFromActiveBuffer(Buffer: Pointer; Size: NativeInt; const APassword: AnsiString = ''); // Buffer must not be released until the document is closed
    procedure LoadFromBytes(const ABytes: TBytes; const APassword: AnsiString = ''); overload;
    procedure LoadFromBytes(const ABytes: TBytes; AIndex: NativeInt; ACount: NativeInt; const APassword: AnsiString = ''); overload;
    procedure LoadFromStream(AStream: TStream; const APassword: AnsiString = '');
    procedure LoadFromFile(const AFileName: string; const APassword: AnsiString = ''; ALoadOption: TPdfDocumentLoadOption = dloMMF);
    procedure Close;

    procedure SaveToFile(const AFileName: string; Option: TPdfDocumentSaveOption = dsoRemoveSecurity; FileVersion: Integer = -1);
    procedure SaveToStream(Stream: TStream; Option: TPdfDocumentSaveOption = dsoRemoveSecurity; FileVersion: Integer = -1);
    procedure SaveToBytes(var Bytes: TBytes; Option: TPdfDocumentSaveOption = dsoRemoveSecurity; FileVersion: Integer = -1);

    function NewDocument: Boolean;
    class function CreateNPagesOnOnePageDocument(Source: TPdfDocument; NewPageWidth, NewPageHeight: Double; NumPagesXAxis, NumPagesYAxis: Integer): TPdfDocument; overload;
    class function CreateNPagesOnOnePageDocument(Source: TPdfDocument; NumPagesXAxis, NumPagesYAxis: Integer): TPdfDocument; overload;
    function ImportAllPages(Source: TPdfDocument; Index: Integer = -1): Boolean;
    function ImportPages(Source: TPdfDocument; const Range: string = ''; Index: Integer = -1): Boolean;
    function ImportPagesByIndex(Source: TPdfDocument; const PageIndices: array of Integer; Index: Integer = -1): Boolean;
    procedure DeletePage(Index: Integer);
    function NewPage(Width, Height: Double; Index: Integer = -1): TPdfPage; overload;
    function NewPage(Index: Integer = -1): TPdfPage; overload;
    function ApplyViewerPreferences(Source: TPdfDocument): Boolean;
    function IsPageLoaded(PageIndex: Integer): Boolean;

    function GetFileIdentifier(IdType: TPdfFileIdType): string;
    function GetMetaText(const TagName: string): string;

    {$IFDEF MSWINDOWS}
    class function SetPrintMode(PrintMode: TPdfPrintMode): Boolean; static;
    class function SetPrintTextWithGDI(UseGdi: Boolean): Boolean; static;
    class function GetPrintTextWithGDI: Boolean; static;
    {$ENDIF}

    property FileName: string read FFileName;
    property PageCount: Integer read GetPageCount;
    property Pages[Index: Integer]: TPdfPage read GetPage;
    property PageSizes[Index: Integer]: TPdfPoint read GetPageSize;

    property Attachments: TPdfAttachmentList read FAttachments;

    property Active: Boolean read GetActive;
    property PrintScaling: Boolean read GetPrintScaling;
    property NumCopies: Integer read GetNumCopies;
    property SecurityHandlerRevision: Integer read GetSecurityHandlerRevision;
    property DocPermissions: Integer read GetDocPermissions;
    property FileVersion: Integer read GetFileVersion;
    property PageMode: TPdfDocumentPageMode read GetPageMode;

    // if UnsupportedFeatures is True, then the document has unsupported features. It is updated
    // after accessing a page.
    property UnsupportedFeatures: Boolean read FUnsupportedFeatures;
    property Handle: FPDF_DOCUMENT read FDocument;
    property FormHandle: FPDF_FORMHANDLE read FForm;

    property FormFieldHighlightColor: TColor read FFormFieldHighlightColor write SetFormFieldHighlightColor default $FFE4DD;
    property FormFieldHighlightAlpha: Integer read FFormFieldHighlightAlpha write SetFormFieldHighlightAlpha default 100;
    property PrintHidesFormFieldHighlight: Boolean read FPrintHidesFormFieldHighlight write FPrintHidesFormFieldHighlight default True;

    property FormModified: Boolean read FFormModified write FFormModified;
    property OnFormInvalidate: TPdfFormInvalidateEvent read FOnFormInvalidate write FOnFormInvalidate;
    property OnFormOutputSelectedRect: TPdfFormOutputSelectedRectEvent read FOnFormOutputSelectedRect write FOnFormOutputSelectedRect;
    property OnFormGetCurrentPage: TPdfFormGetCurrentPageEvent read FOnFormGetCurrentPage write FOnFormGetCurrentPage;
    property OnFormFieldFocus: TPdfFormFieldFocusEvent read FOnFormFieldFocus write FOnFormFieldFocus;
  end;

  TPdfDocumentPrinterStatusEvent = procedure(Sender: TObject; CurrentPageNum, PageCount: Integer) of object;

  TPdfDocumentPrinter = class(TObject)
  private
    FBeginPrintCounter: Integer;

    FPrinterDC: HDC;
    FPrintPortraitOrientation: Boolean;
    FPaperSize: TSize;
    FPrintArea: TSize;
    FMargins: TPoint;

    FPrintTextWithGDI: Boolean;
    FFitPageToPrintArea: Boolean;
    FOnPrintStatus: TPdfDocumentPrinterStatusEvent;

    function IsPortraitOrientation(AWidth, AHeight: Integer): Boolean;
    {$IFDEF MSWINDOWS}
    procedure GetPrinterBounds;
    {$ENDIF}
  protected
    function PrinterStartDoc(const AJobTitle: string): Boolean; virtual; abstract;
    procedure PrinterEndDoc; virtual; abstract;
    procedure PrinterStartPage; virtual; abstract;
    procedure PrinterEndPage; virtual; abstract;
    function GetPrinterDC: HDC; virtual; abstract;

    {$IFDEF MSWINDOWS}
    procedure InternPrintPage(APage: TPdfPage; X, Y, Width, Height: Double);
    {$ENDIF}
  public
    constructor Create;

    {$IFDEF MSWINDOWS}
    { BeginPrint must be called before printing multiple documents.
      Returns false if the printer can't print. (e.g. The user aborted the PDF Printer's FileDialog) }
    function BeginPrint(const AJobTitle: string = ''): Boolean;
    { EndPrint must be called after printing multiple documents were printed. }
    procedure EndPrint;

    { Prints a range of PDF document pages (0..PageCount-1) }
    function Print(ADocument: TPdfDocument; AFromPageIndex, AToPageIndex: Integer): Boolean; overload;
    { Prints all pages of the PDF document. }
    function Print(ADocument: TPdfDocument): Boolean; overload;
    {$ENDIF}

    { If PrintTextWithGDI is true the text on PDF pages are printed with GDI if the font is
      installed on the system. Otherwise the text is converted to vectors. }
    property PrintTextWithGDI: Boolean read FPrintTextWithGDI write FPrintTextWithGDI default False;

    { If FitPageToPrintArea is true the page fill be scaled to fit into the printable area. }
    property FitPageToPrintArea: Boolean read FFitPageToPrintArea write FFitPageToPrintArea default True;

    { OnPrintStatus is triggered after every printed page }
    property OnPrintStatus: TPdfDocumentPrinterStatusEvent read FOnPrintStatus write FOnPrintStatus;
  end;

function SetThreadPdfUnsupportedFeatureHandler(const Handler: TPdfUnsupportedFeatureHandler): TPdfUnsupportedFeatureHandler;

var
  PDFiumDllDir: string = '';
  PDFiumDllFileName: string = ''; // use this instead of PDFiumDllDir if you want to change the DLLs file name
  {$IF declared(FPDF_InitEmbeddedLibraries)}
  PDFiumResDir: string = '';
  {$IFEND}

implementation

resourcestring
  RsUnsupportedFeature = 'Function %s not supported';
  RsArgumentsOutOfRange = 'Function argument "%s" (%d) out of range';
  RsDocumentNotActive = 'PDF document is not open';
  RsFileTooLarge = 'PDF file "%s" is too large';

  RsPdfCannotDeleteAttachmnent = 'Cannot delete the PDF attachment %d';
  RsPdfCannotAddAttachmnent = 'Cannot add the PDF attachment "%s"';
  RsPdfCannotSetAttachmentContent = 'Cannot set the PDF attachment content';
  RsPdfAttachmentContentNotSet = 'Content must be set before accessing string PDF attachmemt values';

  RsPdfErrorSuccess  = 'No error';
  RsPdfErrorUnknown  = 'Unknown error';
  RsPdfErrorFile     = 'File not found or can''t be opened';
  RsPdfErrorFormat   = 'File is not a PDF document or is corrupted';
  RsPdfErrorPassword = 'Password required oder invalid password';
  RsPdfErrorSecurity = 'Security schema is not support';
  RsPdfErrorPage     = 'Page does not exist or data error';

threadvar
  ThreadPdfUnsupportedFeatureHandler: TPdfUnsupportedFeatureHandler;
  UnsupportedFeatureCurrentDocument: TPdfDocument;

var
  GPrintTextWithGDI: Boolean = False;

type
  { We don't want to use a TBytes temporary array if we can convert directly into the destination
    buffer. }
  TEncodingAccess = class(TEncoding)
  public
    function GetMemCharCount(Bytes: PByte; ByteCount: Integer): Integer;
    function GetMemChars(Bytes: PByte; ByteCount: Integer; Chars: PWideChar; CharCount: Integer): Integer;
  end;

function TEncodingAccess.GetMemCharCount(Bytes: PByte; ByteCount: Integer): Integer;
begin
  Result := GetCharCount(Bytes, ByteCount);
end;

function TEncodingAccess.GetMemChars(Bytes: PByte; ByteCount: Integer; Chars: PWideChar; CharCount: Integer): Integer;
begin
  Result := GetChars(Bytes, ByteCount, Chars, CharCount);
end;

function SetThreadPdfUnsupportedFeatureHandler(const Handler: TPdfUnsupportedFeatureHandler): TPdfUnsupportedFeatureHandler;
begin
  Result := ThreadPdfUnsupportedFeatureHandler;
  ThreadPdfUnsupportedFeatureHandler := Handler;
end;

{$IFDEF MSWINDOWS}
{$IF not declared(GetFileSizeEx)}
function GetFileSizeEx(hFile: THandle; var lpFileSize: Int64): Boolean; stdcall;
  external kernel32 name 'GetFileSizeEx';
{$IFEND}
{$IFEND}


procedure SwapInts(var X, Y: Integer);
var
  Tmp: Integer;
begin
  Tmp := X;
  X := Y;
  Y := Tmp;
end;

function GetUnsupportedFeatureName(nType: Integer): string;
begin
  case nType of
    FPDF_UNSP_DOC_XFAFORM:
      Result := 'XFA';

    FPDF_UNSP_DOC_PORTABLECOLLECTION:
      Result := 'Portfolios_Packages';

    FPDF_UNSP_DOC_ATTACHMENT,
    FPDF_UNSP_ANNOT_ATTACHMENT:
      Result := 'Attachment';

    FPDF_UNSP_DOC_SECURITY:
      Result := 'Rights_Management';

    FPDF_UNSP_DOC_SHAREDREVIEW:
      Result := 'Shared_Review';

    FPDF_UNSP_DOC_SHAREDFORM_ACROBAT,
    FPDF_UNSP_DOC_SHAREDFORM_FILESYSTEM,
    FPDF_UNSP_DOC_SHAREDFORM_EMAIL:
      Result := 'Shared_Form';

    FPDF_UNSP_ANNOT_3DANNOT:
      Result := '3D';

    FPDF_UNSP_ANNOT_MOVIE:
      Result := 'Movie';

    FPDF_UNSP_ANNOT_SOUND:
      Result := 'Sound';

    FPDF_UNSP_ANNOT_SCREEN_MEDIA,
    FPDF_UNSP_ANNOT_SCREEN_RICHMEDIA:
      Result := 'Screen';

    FPDF_UNSP_ANNOT_SIG:
      Result := 'Digital_Signature';

  else
    Result := 'Unknown';
  end;
end;

procedure UnsupportedHandler(pThis: PUNSUPPORT_INFO; nType: Integer); cdecl;
var
  Document: TPdfDocument;
begin
  Document := UnsupportedFeatureCurrentDocument;
  if Document <> nil then
    Document.FUnsupportedFeatures := True;

  if Assigned(ThreadPdfUnsupportedFeatureHandler) then
    ThreadPdfUnsupportedFeatureHandler(nType, GetUnsupportedFeatureName(nType));
  //raise EPdfUnsupportedFeatureException.CreateResFmt(@RsUnsupportedFeature, [GetUnsupportedFeatureName]);
end;

var
  PDFiumInitCritSect: TRTLCriticalSection;
  UnsupportInfo: TUnsupportInfo = (
    version: 1;
    FSDK_UnSupport_Handler: UnsupportedHandler;
  );

procedure InitLib;
{$J+}
const
  Initialized: Integer = 0;
{$J-}
begin
  if Initialized = 0 then
  begin
    EnterCriticalSection(PDFiumInitCritSect);
    try
      if Initialized = 0 then
      begin
        if PDFiumDllFileName <> '' then
          InitPDFiumEx(PDFiumDllFileName {$IF declared(FPDF_InitEmbeddedLibraries)}, PDFiumResDir{$IFEND})
        else
          InitPDFium(PDFiumDllDir {$IF declared(FPDF_InitEmbeddedLibraries)}, PDFiumResDir{$IFEND});
        FSDK_SetUnSpObjProcessHandler(@UnsupportInfo);
        Initialized := 1;
      end;
    finally
      LeaveCriticalSection(PDFiumInitCritSect);
    end;
  end;
end;

procedure RaiseLastPdfError;
var
  ret : Longword;
begin
  ret := FPDF_GetLastError;
  case ret of
    FPDF_ERR_SUCCESS:
      raise EPdfException.CreateRes(@RsPdfErrorSuccess);
    FPDF_ERR_FILE:
      raise EPdfException.CreateRes(@RsPdfErrorFile);
    FPDF_ERR_FORMAT:
      raise EPdfException.CreateRes(@RsPdfErrorFormat);
    FPDF_ERR_PASSWORD:
      raise EPdfException.CreateRes(@RsPdfErrorPassword);
    FPDF_ERR_SECURITY:
      raise EPdfException.CreateRes(@RsPdfErrorSecurity);
    FPDF_ERR_PAGE:
      raise EPdfException.CreateRes(@RsPdfErrorPage);
  else
    raise EPdfException.CreateRes(@RsPdfErrorUnknown);
  end;
end;

procedure FFI_Invalidate(pThis: PFPDF_FORMFILLINFO; page: FPDF_PAGE; left, top, right, bottom: Double); cdecl;
var
  Handler: PPdfFormFillHandler;
  Pg: TPdfPage;
  R: TPdfRect;
begin
  Handler := PPdfFormFillHandler(pThis);
  if Assigned(Handler.Document.OnFormInvalidate) then
  begin
    Pg := Handler.Document.FindPage(page);
    if Pg <> nil then
    begin
      R.Left := left;
      R.Top := top;
      R.Right := right;
      R.Bottom := bottom;
      Handler.Document.OnFormInvalidate(Handler.Document, Pg, R);
    end;
  end;
end;

procedure FFI_Change(pThis: PFPDF_FORMFILLINFO); cdecl;
var
  Handler: PPdfFormFillHandler;
begin
  Handler := PPdfFormFillHandler(pThis);
  Handler.Document.FormModified := True;
end;

procedure FFI_OutputSelectedRect(pThis: PFPDF_FORMFILLINFO; page: FPDF_PAGE; left, top, right, bottom: Double); cdecl;
var
  Handler: PPdfFormFillHandler;
  Pg: TPdfPage;
  R: TPdfRect;
begin
  Handler := PPdfFormFillHandler(pThis);
  if Assigned(Handler.Document.OnFormOutputSelectedRect) then
  begin
    Pg := Handler.Document.FindPage(Page);
    if Pg <> nil then
    begin
      R.Left := left;
      R.Top := top;
      R.Right := right;
      R.Bottom := bottom;
      Handler.Document.OnFormOutputSelectedRect(Handler.Document, Pg, R);
    end;
  end;
end;

var
  FFITimers: array of record
    Id: UINT;
    Proc: TFPDFTimerCallback;
  end;
  FFITimersCritSect: TRTLCriticalSection;

procedure FormTimerProc(hwnd: HWND; uMsg: UINT; timerId: UINT; dwTime: DWORD); stdcall;
var
  I: Integer;
  Proc: TFPDFTimerCallback;
begin
  Proc := nil;
  EnterCriticalSection(FFITimersCritSect);
  try
    for I := 0 to Length(FFITimers) - 1 do
    begin
      if FFITimers[I].Id = timerId then
      begin
        Proc := FFITimers[I].Proc;
        Break;
      end;
    end;
  finally
    LeaveCriticalSection(FFITimersCritSect);
  end;

  if Assigned(Proc) then
    Proc(timerId);
end;

function FFI_SetTimer(pThis: PFPDF_FORMFILLINFO; uElapse: Integer; lpTimerFunc: TFPDFTimerCallback): Integer; cdecl;
var
  I: Integer;
  Id: UINT;
begin
  {$IFDEF MSWINDOWS}
  Id := SetTimer(0, 0, uElapse, @FormTimerProc);
  {$ELSE}
  raise Exception.create('Todo');
  {$ENDIF}
  Result := Integer(Id);
  if Id <> 0 then
  begin
    EnterCriticalSection(FFITimersCritSect);
    try
      for I := 0 to Length(FFITimers) - 1 do
      begin
        if FFITimers[I].Id = 0 then
        begin
          FFITimers[I].Id := Id;
          FFITimers[I].Proc := lpTimerFunc;
          Exit;
        end;
      end;
      I := Length(FFITimers);
      SetLength(FFITimers, I + 1);
      FFITimers[I].Id := Id;
      FFITimers[I].Proc := lpTimerFunc;
    finally
      LeaveCriticalSection(FFITimersCritSect);
    end;
  end;
end;

procedure FFI_KillTimer(pThis: PFPDF_FORMFILLINFO; nTimerID: Integer); cdecl;
var
  I: Integer;
begin
  if nTimerID <> 0 then
  begin
    {$IFDEF MSWINDOWS}
    KillTimer(0, nTimerID);
    {$ENDIF}

    EnterCriticalSection(FFITimersCritSect);
    try
      for I := 0 to Length(FFITimers) - 1 do
      begin
        if FFITimers[I].Id = UINT(nTimerID) then
        begin
          FFITimers[I].Id := 0;
          FFITimers[I].Proc := nil;
        end;
      end;

      I := Length(FFITimers) - 1;
      while (I >= 0) and (FFITimers[I].Id = 0) do
        Dec(I);
      SetLength(FFITimers, I + 1);
    finally
      LeaveCriticalSection(FFITimersCritSect);
    end;
  end;
end;

function FFI_GetLocalTime(pThis: PFPDF_FORMFILLINFO): FPDF_SYSTEMTIME; cdecl;
var
  d : TDateTime;
begin
  {$IFDEF MSWINDOWS}
  GetLocalTime(PSystemTime(@Result)^);
  {$ELSE}
  d := Now;
  DecodeDate(d, result.wYear, result.wMonth, result.wDay);
  decodeTime(d, result.wHour, result.wMinute, result.wSecond, result.wMilliseconds);
  {$ENDIF}
end;

function FFI_GetPage(pThis: PFPDF_FORMFILLINFO; document: FPDF_DOCUMENT; nPageIndex: Integer): FPDF_PAGE; cdecl;
var
  Handler: PPdfFormFillHandler;
begin
  Handler := PPdfFormFillHandler(pThis);
  Result := nil;
  if (Handler.Document <> nil) and (Handler.Document.FDocument = document) then
  begin
    if (nPageIndex >= 0) and (nPageIndex < Handler.Document.PageCount) then
      Result := Handler.Document.Pages[nPageIndex].FPage;
  end;
end;

function FFI_GetCurrentPage(pThis: PFPDF_FORMFILLINFO; document: FPDF_DOCUMENT): FPDF_PAGE; cdecl;
var
  Handler: PPdfFormFillHandler;
  Pg: TPdfPage;
begin
  Handler := PPdfFormFillHandler(pThis);
  Result := nil;
  if (Handler.Document <> nil) and (Handler.Document.FDocument = document) and Assigned(Handler.Document.OnFormGetCurrentPage) then
  begin
    Pg := nil;
    Handler.Document.OnFormGetCurrentPage(Handler.Document, Pg);
    Result := nil;
    if Pg <> nil then
      Result := Pg.FPage;
  end;
end;

function FFI_GetRotation(pThis: PFPDF_FORMFILLINFO; page: FPDF_PAGE): Integer; cdecl;
begin
  Result := 0;
end;

procedure FFI_SetCursor(pThis: PFPDF_FORMFILLINFO; nCursorType: Integer); cdecl;
begin
  // A better solution is to use check what form field type is under the mouse cursor in the
  // MoveMove event. Chrome/Edge don't rely on SetCursor either.
end;

procedure FFI_SetTextFieldFocus(pThis: PFPDF_FORMFILLINFO; value: FPDF_WIDESTRING; valueLen: FPDF_DWORD; is_focus: FPDF_BOOL); cdecl;
var
  Handler: PPdfFormFillHandler;
begin
  Handler := PPdfFormFillHandler(pThis);
  if (Handler.Document <> nil) and Assigned(Handler.Document.OnFormFieldFocus) then
    Handler.Document.OnFormFieldFocus(Handler.Document, value, valueLen, is_focus <> 0);
end;

procedure FFI_FocusChange(param: PFPDF_FORMFILLINFO; annot: FPDF_ANNOTATION; page_index: Integer); cdecl;
begin
end;



{ TPdfRect }

procedure TPdfRect.Offset(XOffset, YOffset: Double);
begin
  Left := Left + XOffset;
  Top := Top + YOffset;
  Right := Right + XOffset;
  Bottom := Bottom + YOffset;
end;

class function TPdfRect.Empty: TPdfRect;
begin
  Result.Left := 0;
  Result.Top := 0;
  Result.Right := 0;
  Result.Bottom := 0;
end;

function TPdfRect.GetHeight: Double;
begin
  Result := Bottom - Top;
end;

function TPdfRect.GetWidth: Double;
begin
  Result := Right - Left;
end;

procedure TPdfRect.SetHeight(const Value: Double);
begin
  Bottom := Top + Value;
end;

procedure TPdfRect.SetWidth(const Value: Double);
begin
  Right := Left + Value;
end;

{ TPdfDocument }

constructor TPdfDocument.Create;
begin
  inherited Create;
  FPages := TObjectList.Create;
  FAttachments := TPdfAttachmentList.Create(Self);
  {$IFDEF DELAYED_LOAD}
  FFileHandle := INVALID_HANDLE_VALUE;
  {$ENDIF}
  FFormFieldHighlightColor := $FFE4DD;
  FFormFieldHighlightAlpha := 100;
  FPrintHidesFormFieldHighlight := True;

  InitLib;
end;

destructor TPdfDocument.Destroy;
begin
  Close;
  FAttachments.Free;
  FPages.Free;
  inherited Destroy;
end;

procedure TPdfDocument.Close;
begin
  FClosing := True;
  try
    FPages.Clear;
    FUnsupportedFeatures := False;

    if FDocument <> nil then
    begin
      if FForm <> nil then
      begin
        FORM_DoDocumentAAction(FForm, FPDFDOC_AACTION_WC);
        FPDFDOC_ExitFormFillEnvironment(FForm);
        FForm := nil;
      end;

      FPDF_CloseDocument(FDocument);
      FDocument := nil;
    end;

    if FCustomLoadData <> nil then
    begin
      Dispose(FCustomLoadData);
      FCustomLoadData := nil;
    end;

    {$IFDEF DELAYED_LOAD}
    if FFileMapping <> 0 then
    begin
      if FBuffer <> nil then
      begin
        UnmapViewOfFile(FBuffer);
        FBuffer := nil;
      end;
      CloseHandle(FFileMapping);
      FFileMapping := 0;
    end
    else if FBuffer <> nil then
    begin
      FreeMem(FBuffer);
      FBuffer := nil;
    end;
    FBytes := nil;

    if FFileHandle <> INVALID_HANDLE_VALUE then
    begin
      CloseHandle(FFileHandle);
      FFileHandle := INVALID_HANDLE_VALUE;
    end;
    {$ENDIF}

    FFileName := '';
    FFormModified := False;
  finally
    FClosing := False;
  end;
end;

{$IFDEF DELAYED_LOAD}
function ReadFromActiveFile(Param: Pointer; Position: LongWord; Buffer: PByte; Size: LongWord): Boolean;
var
  NumRead: DWORD;
begin
  if Buffer <> nil then
  begin
    SetFilePointer(THandle(Param), Position, nil, FILE_BEGIN);
    Result := ReadFile(THandle(Param), Buffer^, Size, NumRead, nil) and (NumRead = Size);
  end
  else
    Result := Size = 0;
end;
{$ENDIF}

procedure TPdfDocument.LoadFromFile(const AFileName: string; const APassword: AnsiString; ALoadOption: TPdfDocumentLoadOption);
var
  Size: Int64;
  Offset: NativeInt;
  NumRead: DWORD;
  LastError: DWORD;
begin
  Close;
  {$IFDEF DELAYED_LOAD}
  FFileHandle := CreateFile(PChar(AFileName), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  if FFileHandle = INVALID_HANDLE_VALUE then
    RaiseLastOSError;
  try
    if not GetFileSizeEx(FFileHandle, Size) then
      RaiseLastOSError;
    if Size > High(Integer) then // PDFium can only handle PDFs up to 2 GB (FX_FILESIZE in core/fxcrt/fx_system.h)
    begin
      {$IFDEF CPUX64}
      // FPDF_LoadCustomDocument wasn't updated to load larger files, so we fall back to MMF.
      if ALoadOption = dloOnDemand then
        ALoadOption := dloMMF;
      {$ELSE}
      raise EPdfException.CreateResFmt(@RsFileTooLarge, [ExtractFileName(AFileName)]);
      {$ENDIF CPUX64}
    end;

    case ALoadOption of
      dloMemory:
        begin
          if Size > 0 then
          begin
            try
              GetMem(FBuffer, Size);
              Offset := 0;
              while Offset < Size do
              begin
                if ((Size - Offset) and not $FFFFFFFF) <> 0 then
                  NumRead := $40000000
                else
                  NumRead := Size - Offset;

                if not ReadFile(FFileHandle, FBuffer[Offset], NumRead, NumRead, nil) then
                begin
                  LastError := GetLastError;
                  FreeMem(FBuffer);
                  FBuffer := nil;
                  RaiseLastOSError(LastError);
                end;
                Inc(Offset, NumRead);
              end;
            finally
              CloseHandle(FFileHandle);
              FFileHandle := INVALID_HANDLE_VALUE;
            end;

            InternLoadFromMem(FBuffer, Size, APassword);
          end;
        end;

      dloMMF:
        begin
          FFileMapping := CreateFileMapping(FFileHandle, nil, PAGE_READONLY, 0, 0, nil);
          if FFileMapping = 0 then
            RaiseLastOSError;
          FBuffer := MapViewOfFile(FFileMapping, FILE_MAP_READ, 0, 0, Size);
          if FBuffer = nil then
            RaiseLastOSError;

          InternLoadFromMem(FBuffer, Size, APassword);
        end;

      dloOnDemand:
        InternLoadFromCustom(ReadFromActiveFile, Size, Pointer(FFileHandle), APassword);
    end;
  except
    Close;
    raise;
  end;
  {$ELSE}
  FDocument := FPDF_LoadDocument(PAnsiChar(AFilename), PAnsiChar(APassword));
  DocumentLoaded;
  {$ENDIF}
  FFileName := AFileName;
end;

procedure TPdfDocument.LoadFromStream(AStream: TStream; const APassword: AnsiString);
var
  Size: NativeInt;
  {$IFNDEF DELAYED_LOAD}
  buffer: PByte;
  {$ENDIF}
begin
  Close;
  Size := AStream.Size;
  if Size > 0 then
  begin
    {$IFDEF DELAYED_LOAD}
    GetMem(FBuffer, Size);
    try
      AStream.ReadBuffer(FBuffer^, Size);
      InternLoadFromMem(FBuffer, Size, APassword);
    except
      Close;
      raise;
    end;
    {$ELSE}
    try
      GetMem(buffer, Size);
      try
        AStream.ReadBuffer(buffer^, Size);
        FDocument := FPDF_LoadMemDocument(buffer, size, PAnsiChar(APassword));
      finally
        FreeMem(buffer);
      end;
    except
      Close;
      raise;
    end;
    {$ENDIF}
  end;
end;

procedure TPdfDocument.LoadFromActiveBuffer(Buffer: Pointer; Size: NativeInt; const APassword: AnsiString);
begin
  Close;
  InternLoadFromMem(Buffer, Size, APassword);
end;

procedure TPdfDocument.LoadFromBytes(const ABytes: TBytes; const APassword: AnsiString);
begin
  LoadFromBytes(ABytes, 0, Length(ABytes), APassword);
end;

procedure TPdfDocument.LoadFromBytes(const ABytes: TBytes; AIndex, ACount: NativeInt; const APassword: AnsiString);
var
  Len: NativeInt;
begin
  Close;

  Len := Length(ABytes);
  if AIndex >= Len then
    raise EPdfArgumentOutOfRange.CreateResFmt(@RsArgumentsOutOfRange, ['Index', AIndex]);
  if AIndex + ACount > Len then
    raise EPdfArgumentOutOfRange.CreateResFmt(@RsArgumentsOutOfRange, ['Count', ACount]);

  {$IFDEF DELAYED_LOAD}
  FBytes := ABytes; // keep alive after return
  InternLoadFromMem(@ABytes[AIndex], ACount, APassword);
  {$ELSE}
  FDocument := FPDF_LoadMemDocument(@ABytes[AIndex], ACount, PAnsiChar(APassword));
  {$ENDIF}
end;

function ReadFromActiveStream(Param: Pointer; Position: LongWord; Buffer: PByte; Size: LongWord): Boolean;
begin
  if Buffer <> nil then
  begin
    TStream(Param).Seek(Position, TSeekOrigin.soBeginning);
    Result := TStream(Param).Read(Buffer^, Size) = Integer(Size);
  end
  else
    Result := Size = 0;
end;

procedure TPdfDocument.LoadFromActiveStream(Stream: TStream; const APassword: AnsiString);
begin
  if Stream = nil then
    Close
  else
    LoadFromCustom(ReadFromActiveStream, Stream.Size, Stream, APassword);
end;

procedure TPdfDocument.LoadFromCustom(ReadFunc: TPdfDocumentCustomReadProc; ASize: LongWord;
  AParam: Pointer; const APassword: AnsiString);
begin
  Close;
  InternLoadFromCustom(ReadFunc, ASize, AParam, APassword);
end;

function GetLoadFromCustomBlock(Param: Pointer; Position: LongWord; Buffer: PByte; Size: LongWord): Integer; cdecl;
var
  Data: TPdfDocument.PCustomLoadDataRec;
begin
  Data := TPdfDocument(param).FCustomLoadData;
  Result := Ord(Data.GetBlock(Data.Param, Position, Buffer, Size));
end;

procedure TPdfDocument.InternLoadFromCustom(ReadFunc: TPdfDocumentCustomReadProc; ASize: LongWord;
  AParam: Pointer; const APassword: AnsiString);
var
  OldCurDoc: TPdfDocument;
begin
  if Assigned(ReadFunc) then
  begin
    New(FCustomLoadData);
    FCustomLoadData.Param := AParam;
    FCustomLoadData.GetBlock := ReadFunc;
    FCustomLoadData.FileAccess.m_FileLen := ASize;
    FCustomLoadData.FileAccess.m_GetBlock := GetLoadFromCustomBlock;
    FCustomLoadData.FileAccess.m_Param := Self;

    OldCurDoc := UnsupportedFeatureCurrentDocument;
    try
      UnsupportedFeatureCurrentDocument := Self;
      FDocument := FPDF_LoadCustomDocument(@FCustomLoadData.FileAccess, PAnsiChar(APassword));
      DocumentLoaded;
    finally
      UnsupportedFeatureCurrentDocument := OldCurDoc;
    end;
  end;
end;

procedure TPdfDocument.InternLoadFromMem(Buffer: PByte; Size: NativeInt; const APassword: AnsiString);
var
  OldCurDoc: TPdfDocument;
begin
  if Size > 0 then
  begin
    OldCurDoc := UnsupportedFeatureCurrentDocument;
    try
      UnsupportedFeatureCurrentDocument := Self;
      FDocument := FPDF_LoadMemDocument64(Buffer, Size, PAnsiChar(Pointer(APassword)));
    finally
      UnsupportedFeatureCurrentDocument := OldCurDoc;
    end;
    DocumentLoaded;
  end;
end;

procedure TPdfDocument.DocumentLoaded;
begin
  FFormModified := False;
  if FDocument = nil then
    RaiseLastPdfError;

  FPages.Count := FPDF_GetPageCount(FDocument);

  FillChar(FFormFillHandler, SizeOf(TPdfFormFillHandler), 0);
  FFormFillHandler.Document := Self;
  FFormFillHandler.FormFillInfo.version := 1; // will be set to 2 if we use an XFA-enabled DLL
  FFormFillHandler.FormFillInfo.FFI_Invalidate := FFI_Invalidate;
  FFormFillHandler.FormFillInfo.FFI_OnChange := FFI_Change;
  FFormFillHandler.FormFillInfo.FFI_OutputSelectedRect := FFI_OutputSelectedRect;
  FFormFillHandler.FormFillInfo.FFI_SetTimer := FFI_SetTimer;
  FFormFillHandler.FormFillInfo.FFI_KillTimer := FFI_KillTimer;
  FFormFillHandler.FormFillInfo.FFI_GetLocalTime := FFI_GetLocalTime;
  FFormFillHandler.FormFillInfo.FFI_GetPage := FFI_GetPage;
  FFormFillHandler.FormFillInfo.FFI_GetCurrentPage := FFI_GetCurrentPage;
  FFormFillHandler.FormFillInfo.FFI_GetRotation := FFI_GetRotation;
  FFormFillHandler.FormFillInfo.FFI_SetCursor := FFI_SetCursor;
  FFormFillHandler.FormFillInfo.FFI_SetTextFieldFocus := FFI_SetTextFieldFocus;
  FFormFillHandler.FormFillInfo.FFI_OnFocusChange := FFI_FocusChange;

  if PDF_USE_XFA then
  begin
    FFormFillHandler.FormFillInfo.version := 2;
    FFormFillHandler.FormFillInfo.xfa_disabled := 1; // Disable XFA support for now
  end;

  FForm := FPDFDOC_InitFormFillEnvironment(FDocument, @FFormFillHandler.FormFillInfo);
  if FForm <> nil then
  begin
    UpdateFormFieldHighlight;

    FORM_DoDocumentJSAction(FForm);
    FORM_DoDocumentOpenAction(FForm);
  end;
end;

procedure TPdfDocument.UpdateFormFieldHighlight;
begin
  FPDF_SetFormFieldHighlightColor(FForm, 0, {ColorToRGB}(FFormFieldHighlightColor));
  FPDF_SetFormFieldHighlightAlpha(FForm, FFormFieldHighlightAlpha);
end;

function TPdfDocument.IsPageLoaded(PageIndex: Integer): Boolean;
var
  Page: TPdfPage;
begin
  Page := TPdfPage(FPages[PageIndex]);
  Result := (Page <> nil) and Page.IsLoaded;
end;

function TPdfDocument.GetPage(Index: Integer): TPdfPage;
var
  LPage: FPDF_PAGE;
begin
  Result := TPdfPage(FPages[Index]);
  if Result = nil then
  begin
    LPage := FPDF_LoadPage(FDocument, Index);
    if LPage = nil then
      RaiseLastPdfError;
    Result := TPdfPage.Create(Self, LPage);
    FPages[Index] := Result;
  end
end;

function TPdfDocument.GetPageCount: Integer;
begin
  Result := FPages.Count;
end;

procedure TPdfDocument.ExtractPage(APage: TPdfPage);
begin
  if not FClosing then
    FPages.Extract(APage);
end;

function TPdfDocument.ReloadPage(APage: TPdfPage): FPDF_PAGE;
var
  Index: Integer;
begin
  CheckActive;
  Index := FPages.IndexOf(APage);
  Result := FPDF_LoadPage(FDocument, Index);
  if Result = nil then
    RaiseLastPdfError;
end;

function TPdfDocument.GetPrintScaling: Boolean;
begin
  CheckActive;
  Result := FPDF_VIEWERREF_GetPrintScaling(FDocument) <> 0;
end;

function TPdfDocument.GetActive: Boolean;
begin
  Result := FDocument <> nil;
end;

procedure TPdfDocument.CheckActive;
begin
  if not Active then
    raise EPdfException.CreateRes(@RsDocumentNotActive);
end;

class function TPdfDocument.CreateNPagesOnOnePageDocument(Source: TPdfDocument;
  NumPagesXAxis, NumPagesYAxis: Integer): TPdfDocument;
begin
  if Source.PageCount > 0 then
    Result := CreateNPagesOnOnePageDocument(Source, Source.PageSizes[0].X, Source.PageSizes[0].Y, NumPagesXAxis, NumPagesYAxis)
  else
    Result := CreateNPagesOnOnePageDocument(Source, PdfDefaultPageWidth, PdfDefaultPageHeight, NumPagesXAxis, NumPagesYAxis); // DIN A4 page
end;

class function TPdfDocument.CreateNPagesOnOnePageDocument(Source: TPdfDocument;
  NewPageWidth, NewPageHeight: Double; NumPagesXAxis, NumPagesYAxis: Integer): TPdfDocument;
begin
  Result := TPdfDocument.Create;
  try
    if (Source = nil) or not Source.Active then
      Result.NewDocument
    else
    begin
      Result.FDocument := FPDF_ImportNPagesToOne(Source.FDocument, NewPageWidth, NewPageHeight, NumPagesXAxis, NumPagesYAxis);
      if Result.FDocument <> nil then
        Result.DocumentLoaded
      else
        Result.NewDocument;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TPdfDocument.InternImportPages(Source: TPdfDocument; PageIndices: PInteger; PageIndicesCount: Integer;
  const Range: AnsiString; Index: Integer; ImportByRange: Boolean): Boolean;
var
  I, NewCount, OldCount, InsertCount: Integer;
begin
  CheckActive;
  Source.CheckActive;

  OldCount := FPDF_GetPageCount(FDocument);
  if Index < 0 then
    Index := OldCount;

  if ImportByRange then // Range = '' => Import all pages
    Result := FPDF_ImportPages(FDocument, Source.FDocument, PAnsiChar(Pointer(Range)), Index) <> 0
  else
    Result := FPDF_ImportPagesByIndex(FDocument, Source.FDocument, PageIndices, PageIndicesCount, Index) <> 0;

  NewCount := FPDF_GetPageCount(FDocument);
  InsertCount := NewCount - OldCount;
  if InsertCount > 0 then
  begin
    FPages.Count := NewCount;
    if Index < OldCount then
    begin
      Move(FPages.List[Index], FPages.List[Index + InsertCount], (OldCount - Index) * SizeOf(TObject));
      for I := Index to Index + InsertCount - 1 do
        FPages.List[Index] := nil;
    end;
  end;
end;

function TPdfDocument.ImportAllPages(Source: TPdfDocument; Index: Integer): Boolean;
begin
  Result := InternImportPages(Source, nil, 0, '', Index, False);
end;

function TPdfDocument.ImportPages(Source: TPdfDocument; const Range: string; Index: Integer): Boolean;
begin
  Result := InternImportPages(Source, nil, 0, AnsiString(Range), Index, True)
end;

function TPdfDocument.ImportPagesByIndex(Source: TPdfDocument; const PageIndices: array of Integer; Index: Integer = -1): Boolean;
begin
  if Length(PageIndices) > 0 then
    Result := InternImportPages(Source, @PageIndices[0], Length(PageIndices), '', Index, False)
  else
    Result := ImportAllPages(Source, Index);
end;

procedure TPdfDocument.SaveToFile(const AFileName: string; Option: TPdfDocumentSaveOption; FileVersion: Integer);
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(AFileName, fmCreate or fmShareDenyWrite);
  try
    SaveToStream(Stream, Option, FileVersion);
  finally
    Stream.Free;
  end;
end;

type
  PFPDFFileWriteEx = ^TFPDFFileWriteEx;
  TFPDFFileWriteEx = record
    Inner: TFPDFFileWrite; // emulate object inheritance
    Stream: TStream;
  end;

function WriteBlockToStream(pThis: PFPDF_FILEWRITE; pData: Pointer; size: LongWord): Integer; cdecl;
begin
  Result := Ord(LongWord(PFPDFFileWriteEx(pThis).Stream.Write(pData^, size)) = size);
end;

procedure TPdfDocument.SaveToStream(Stream: TStream; Option: TPdfDocumentSaveOption; FileVersion: Integer);
var
  FileWriteInfo: TFPDFFileWriteEx;
begin
  CheckActive;

  FileWriteInfo.Inner.version := 1;
  FileWriteInfo.Inner.WriteBlock := @WriteBlockToStream;
  FileWriteInfo.Stream := Stream;

  if FForm <> nil then
  begin
    FORM_ForceToKillFocus(FForm); // also save the form field data that is currently focused
    FORM_DoDocumentAAction(FForm, FPDFDOC_AACTION_WS); // BeforeSave
  end;

  if FileVersion <> -1 then
    FPDF_SaveWithVersion(FDocument, @FileWriteInfo, Ord(Option), FileVersion)
  else
    FPDF_SaveAsCopy(FDocument, @FileWriteInfo, Ord(Option));

  if FForm <> nil then
    FORM_DoDocumentAAction(FForm, FPDFDOC_AACTION_DS); // AfterSave
end;

procedure TPdfDocument.SaveToBytes(var Bytes: TBytes; Option: TPdfDocumentSaveOption; FileVersion: Integer);
var
  Stream: TBytesStream;
  Size: NativeInt;
begin
  CheckActive;

  Stream := TBytesStream.Create(nil);
  try
    SaveToStream(Stream, Option, FileVersion);
    Size := Stream.Size;
    Bytes := Stream.Bytes;
  finally
    Stream.Free;
  end;
  // Trim the byte array from the stream's capacity to the actual size
  if Length(Bytes) <> Size then
    SetLength(Bytes, Size);
end;

function TPdfDocument.NewDocument: Boolean;
begin
  Close;
  FDocument := FPDF_CreateNewDocument;
  Result := FDocument <> nil;
  FFormModified := False;
end;

procedure TPdfDocument.DeletePage(Index: Integer);
begin
  CheckActive;
  FPages.Delete(Index);
  FPDFPage_Delete(FDocument, Index);
end;

function TPdfDocument.NewPage(Width, Height: Double; Index: Integer): TPdfPage;
var
  LPage: FPDF_PAGE;
begin
  CheckActive;
  if Index < 0 then
    Index := FPages.Count; // append new page
  LPage := FPDFPage_New(FDocument, Index, Width, Height);
  if LPage <> nil then
  begin
    Result := TPdfPage.Create(Self, LPage);
    FPages.Insert(Index, Result);
  end
  else
    Result := nil;
end;

function TPdfDocument.NewPage(Index: Integer = -1): TPdfPage;
begin
  Result := NewPage(PdfDefaultPageWidth, PdfDefaultPageHeight, Index);
end;

function TPdfDocument.ApplyViewerPreferences(Source: TPdfDocument): Boolean;
begin
  CheckActive;
  Source.CheckActive;
  Result := FPDF_CopyViewerPreferences(FDocument, Source.FDocument) <> 0;
end;

function TPdfDocument.GetFileIdentifier(IdType: TPdfFileIdType): string;
var
  Len: Integer;
  A: AnsiString;
begin
  CheckActive;
  Len := FPDF_GetFileIdentifier(FDocument, FPDF_FILEIDTYPE(IdType), nil, 0) div SizeOf(AnsiChar) - 1;
  if Len > 0 then
  begin
    SetLength(A, Len);
    FPDF_GetFileIdentifier(FDocument, FPDF_FILEIDTYPE(IdType), PAnsiChar(A), (Len + 1) * SizeOf(AnsiChar));
    Result := string(A);
  end
  else
    Result := '';
end;

function TPdfDocument.GetMetaText(const TagName: string): string;
var
  Len: Integer;
  A: AnsiString;
begin
  CheckActive;
  A := AnsiString(TagName);
  Len := FPDF_GetMetaText(FDocument, PAnsiChar(A), nil, 0) div SizeOf(WideChar) - 1;
  if Len > 0 then
  begin
    SetLength(Result, Len);
    FPDF_GetMetaText(FDocument, PAnsiChar(A), PChar(Result), (Len + 1) * SizeOf(WideChar));
  end
  else
    Result := '';
end;

function TPdfDocument.GetSecurityHandlerRevision: Integer;
begin
  CheckActive;
  Result := FPDF_GetSecurityHandlerRevision(FDocument);
end;

function TPdfDocument.GetDocPermissions: Integer;
begin
  CheckActive;
  Result := Integer(FPDF_GetDocPermissions(FDocument));
end;

function TPdfDocument.GetFileVersion: Integer;
begin
  CheckActive;
  if FPDF_GetFileVersion(FDocument, Result) = 0 then
    Result := 0;
end;

function TPdfDocument.GetPageSize(Index: Integer): TPdfPoint;
var
  SizeF: TFSSizeF;
begin
  CheckActive;
  Result.X := 0;
  Result.Y := 0;
  if FPDF_GetPageSizeByIndexF(FDocument, Index, @SizeF) <> 0 then
  begin
    Result.X := SizeF.width;
    Result.Y := SizeF.height;
  end;
end;

function TPdfDocument.GetPageMode: TPdfDocumentPageMode;
begin
  CheckActive;
  Result := TPdfDocumentPageMode(FPDFDoc_GetPageMode(FDocument));
end;

function TPdfDocument.GetNumCopies: Integer;
begin
  CheckActive;
  Result := FPDF_VIEWERREF_GetNumCopies(FDocument);
end;

{$IFDEF MSWINDOWS}
class function TPdfDocument.SetPrintMode(PrintMode: TPdfPrintMode): Boolean;
begin
  InitLib;
  Result := FPDF_SetPrintMode(Ord(PrintMode)) <> 0;
end;

class function TPdfDocument.SetPrintTextWithGDI(UseGdi: Boolean): Boolean;
begin
  InitLib;
  FPDF_SetPrintTextWithGDI(Ord(UseGdi));
  Result := GPrintTextWithGDI;
  GPrintTextWithGDI := UseGdi;
end;

class function TPdfDocument.GetPrintTextWithGDI: Boolean;
begin
  Result := GPrintTextWithGDI;
end;
{$ENDIF}

procedure TPdfDocument.SetFormFieldHighlightAlpha(Value: Integer);
begin
  if Value < 0 then
    Value := 0;
  if Value > 255 then
    Value := 255;

  if Value <> FFormFieldHighlightAlpha then
  begin
    FFormFieldHighlightAlpha := Value;
    if Active then
      FPDF_SetFormFieldHighlightAlpha(FForm, FFormFieldHighlightAlpha);
  end;
end;

procedure TPdfDocument.SetFormFieldHighlightColor(const Value: TColor);
begin
  if Value <> FFormFieldHighlightColor then
  begin
    FFormFieldHighlightColor := Value;
    if Active then
      FPDF_SetFormFieldHighlightColor(FForm, 0, {ColorToRGB}(FFormFieldHighlightColor));
  end;
end;

function TPdfDocument.FindPage(Page: FPDF_PAGE): TPdfPage;
var
  I: Integer;
begin
  // The page must be already loaded
  for I := 0 to PageCount - 1 do
  begin
    Result := TPdfPage(FPages[I]);
    if (Result <> nil) and (Result.FPage = Page) then
      Exit;
  end;
  Result := nil;
end;

{ TPdfPage }

constructor TPdfPage.Create(ADocument: TPdfDocument; APage: FPDF_PAGE);
var
  i : integer;
begin
  inherited Create;
  FDocument := ADocument;
  FPage := APage;
  FObjects := TObjectList{<TPDFObject>}.create;
  FObjects.OwnsObjects := true;
  if BeginText then
    for i := 0 to FPDFPage_CountObjects(APage) - 1 do
      FObjects.Add(TPDFObject.Create(FPDFPage_GetObject(APage, i), FTextHandle));
  AfterOpen;
end;

destructor TPdfPage.Destroy;
begin
  Close;
  FObjects.Free;
  FDocument.ExtractPage(Self);
  inherited Destroy;
end;

function TPdfPage.IsValidForm: Boolean;
begin
  Result := (FDocument <> nil) and (FDocument.FForm <> nil) and (FPage <> nil);
end;

procedure TPdfPage.AfterOpen;
var
  OldCurDoc: TPdfDocument;
begin
  if IsValidForm then
  begin
    OldCurDoc := UnsupportedFeatureCurrentDocument;
    try
      UnsupportedFeatureCurrentDocument := FDocument;
      FORM_OnAfterLoadPage(FPage, FDocument.FForm);
      FORM_DoPageAAction(FPage, FDocument.FForm, FPDFPAGE_AACTION_OPEN);
    finally
      UnsupportedFeatureCurrentDocument := OldCurDoc;
    end;
  end;

  UpdateMetrics;
end;

procedure TPdfPage.Close;
begin
  if IsValidForm then
  begin
    FORM_DoPageAAction(FPage, FDocument.FForm, FPDFPAGE_AACTION_CLOSE);
    FORM_OnBeforeClosePage(FPage, FDocument.FForm);
  end;

  if FLinkHandle <> nil then
  begin
    FPDFLink_CloseWebLinks(FLinkHandle);
    FLinkHandle := nil;
  end;
  if FSearchHandle <> nil then
  begin
    FPDFText_FindClose(FSearchHandle);
    FSearchHandle := nil;
  end;
  if FTextHandle <> nil then
  begin
    FPDFText_ClosePage(FTextHandle);
    FTextHandle := nil;
  end;
  if FPage <> nil then
  begin
    FPDF_ClosePage(FPage);
    FPage := nil;
  end;
end;

procedure TPdfPage.Open;
begin
  if FPage = nil then
  begin
    FPage := FDocument.ReloadPage(Self);
    AfterOpen;
  end;
end;

class function TPdfPage.GetDrawFlags(const Options: TPdfPageRenderOptions): Integer;
begin
  Result := 0;
  if proAnnotations in Options then
    Result := Result or FPDF_ANNOT;
  if proLCDOptimized in Options then
    Result := Result or FPDF_LCD_TEXT;
  if proNoNativeText in Options then
    Result := Result or FPDF_NO_NATIVETEXT;
  if proNoCatch in Options then
    Result := Result or FPDF_NO_CATCH;
  if proLimitedImageCacheSize in Options then
    Result := Result or FPDF_RENDER_LIMITEDIMAGECACHE;
  if proForceHalftone in Options then
    Result := Result or FPDF_RENDER_FORCEHALFTONE;
  if proPrinting in Options then
    Result := Result or FPDF_PRINTING;
  if proReverseByteOrder in Options then
    Result := Result or FPDF_REVERSE_BYTE_ORDER;
end;

procedure TPdfPage.Draw(DC: HDC; X, Y, Width, Height: Integer; Rotate: TPdfPageRotation; const Options: TPdfPageRenderOptions);
var
  BitmapInfo: TBitmapInfo;
  Bmp, OldBmp: HBITMAP;
  BmpBits: Pointer;
  PdfBmp: TPdfBitmap;
  BmpDC: HDC;
begin
  Open;

  {$IFDEF MSWINDOWS}
  if proPrinting in Options then
  begin
    FPDF_RenderPage(DC, FPage, X, Y, Width, Height, Ord(Rotate), GetDrawFlags(Options));
    Exit;
  end;
  {$ENDIF}

  FillChar(BitmapInfo, SizeOf(BitmapInfo), 0);
  BitmapInfo.bmiHeader.biSize := SizeOf(BitmapInfo);
  BitmapInfo.bmiHeader.biWidth := Width;
  BitmapInfo.bmiHeader.biHeight := -Height;
  BitmapInfo.bmiHeader.biPlanes := 1;
  BitmapInfo.bmiHeader.biBitCount := 32;
  BitmapInfo.bmiHeader.biCompression := BI_RGB;
  BmpBits := nil;
  Bmp := CreateDIBSection(DC, BitmapInfo, DIB_RGB_COLORS, BmpBits, 0, 0);
  if Bmp <> 0 then
  begin
    try
      PdfBmp := TPdfBitmap.Create(Width, Height, bfBGRA, BmpBits, Width * 4);
      try
        if Transparency then
          PdfBmp.FillRect(0, 0, Width, Height, $00FFFFFF)
        else
          PdfBmp.FillRect(0, 0, Width, Height, $FFFFFFFF);
        DrawToPdfBitmap(PdfBmp, 0, 0, Width, Height, Rotate, Options);
        DrawFormToPdfBitmap(PdfBmp, 0, 0, Width, Height, Rotate, Options);
      finally
        PdfBmp.Free;
      end;

      BmpDC := CreateCompatibleDC(DC);
      OldBmp := SelectObject(BmpDC, Bmp);
      BitBlt(DC, X, Y, Width, Height, BmpDC, 0, 0, SRCCOPY);
      SelectObject(BmpDC, OldBmp);
      DeleteDC(BmpDC);
    finally
      DeleteObject(Bmp);
    end;
  end;
end;

procedure TPdfPage.DrawToPdfBitmap(APdfBitmap: TPdfBitmap; X, Y, Width, Height: Integer;
  Rotate: TPdfPageRotation; const Options: TPdfPageRenderOptions);
begin
  Open;
  FPDF_RenderPageBitmap(APdfBitmap.FBitmap, FPage, X, Y, Width, Height, Ord(Rotate), GetDrawFlags(Options));
end;

procedure TPdfPage.DrawFormToPdfBitmap(APdfBitmap: TPdfBitmap; X, Y, Width, Height: Integer;
  Rotate: TPdfPageRotation; const Options: TPdfPageRenderOptions);
begin
  Open;
  if IsValidForm then
  begin
    if proPrinting in Options then
    begin
      if FDocument.PrintHidesFormFieldHighlight then
        FPDF_RemoveFormFieldHighlight(FDocument.FForm);
        //FPDF_SetFormFieldHighlightAlpha(FDocument.FForm, 0); // hide the highlight
      FormEventKillFocus;
    end;
    try
      FPDF_FFLDraw(FDocument.FForm, APdfBitmap.FBitmap, FPage, X, Y, Width, Height, Ord(Rotate), GetDrawFlags(Options));
    finally
      if (proPrinting in Options) and FDocument.PrintHidesFormFieldHighlight then
        FDocument.UpdateFormFieldHighlight;
    end;
  end;
end;

procedure TPdfPage.UpdateMetrics;
begin
  FWidth := FPDF_GetPageWidthF(FPage);
  FHeight := FPDF_GetPageHeightF(FPage);
  FTransparency := FPDFPage_HasTransparency(FPage) <> 0;
  FRotation := TPdfPageRotation(FPDFPage_GetRotation(FPage));
end;

function TPdfPage.DeviceToPage(X, Y, Width, Height: Integer; DeviceX, DeviceY: Integer; Rotate: TPdfPageRotation): TPdfPoint;
begin
  Open;
  FPDF_DeviceToPage(FPage, X, Y, Width, Height, Ord(Rotate), DeviceX, DeviceY, Result.X, Result.Y);
end;

function TPdfPage.PageToDevice(X, Y, Width, Height: Integer; PageX, PageY: Double;
  Rotate: TPdfPageRotation): TPoint;
begin
  Open;
  FPDF_PageToDevice(FPage, X, Y, Width, Height, Ord(Rotate), PageX, PageY, Result.X, Result.Y);
end;

function TPdfPage.DeviceToPage(X, Y, Width, Height: Integer; const R: TRect; Rotate: TPdfPageRotation): TPdfRect;
begin
  Result.TopLeft := DeviceToPage(X, Y, Width, Height, R.Left, R.Top, Rotate);
  Result.BottomRight := DeviceToPage(X, Y, Width, Height, R.Right, R.Bottom, Rotate);
end;

function TPdfPage.PageToDevice(X, Y, Width, Height: Integer; const R: TPdfRect; Rotate: TPdfPageRotation): TRect;
var
  T: Integer;
begin
  Result.TopLeft := PageToDevice(X, Y, Width, Height, R.Left, R.Top, Rotate);
  Result.BottomRight := PageToDevice(X, Y, Width, Height, R.Right, R.Bottom, Rotate);
  if Result.Top > Result.Bottom then
  begin
    T := Result.Top;
    Result.Top := Result.Bottom;
    Result.Bottom := T;
  end;
end;

procedure TPdfPage.SetRotation(const Value: TPdfPageRotation);
begin
  Open;
  FPDFPage_SetRotation(FPage, Ord(Value));
  FRotation := TPdfPageRotation(FPDFPage_GetRotation(FPage));
end;

function TPdfPage.AllText: String;
var
  c : integer;
  s : String;
begin
  result := '';
  if BeginText then
  begin
    c := 0;
    repeat
      s := ReadText(c, 100);
      inc(c, 100);
      result := result + s;
    until s = '';
  end;
end;

procedure TPdfPage.ApplyChanges;
begin
  if FPage <> nil then
    FPDFPage_GenerateContent(FPage);
end;

function TPdfPage.BeginText: Boolean;
begin
  if FTextHandle = nil then
  begin
    Open;
    FTextHandle := FPDFText_LoadPage(FPage);
  end;
  Result := FTextHandle <> nil;
end;

function TPdfPage.BeginWebLinks: Boolean;
begin
  if (FLinkHandle = nil) and BeginText then
    FLinkHandle := FPDFLink_LoadWebLinks(FTextHandle);
  Result := FLinkHandle <> nil;
end;

function TPdfPage.BeginFind(const SearchString: WideString; MatchCase,
  MatchWholeWord: Boolean; FromEnd: Boolean): Boolean;
var
  Flags, StartIndex: Integer;
begin
  EndFind;
  if BeginText then
  begin
    Flags := 0;
    if MatchCase then
      Flags := Flags or FPDF_MATCHCASE;
    if MatchWholeWord then
      Flags := Flags or FPDF_MATCHWHOLEWORD;

    if FromEnd then
      StartIndex := -1
    else
      StartIndex := 0;

    FSearchHandle := FPDFText_FindStart(FTextHandle, PWideChar(SearchString), Flags, StartIndex);
  end;
  Result := FSearchHandle <> nil;
end;

procedure TPdfPage.EndFind;
begin
  if FSearchHandle <> nil then
  begin
    FPDFText_FindClose(FSearchHandle);
    FSearchHandle := nil;
  end;
end;

function TPdfPage.FindNext(var CharIndex, Count: Integer): Boolean;
begin
  CharIndex := 0;
  Count := 0;
  if FSearchHandle <> nil then
  begin
    Result := FPDFText_FindNext(FSearchHandle) <> 0;
    if Result then
    begin
      CharIndex := FPDFText_GetSchResultIndex(FSearchHandle);
      Count := FPDFText_GetSchCount(FSearchHandle);
    end;
  end
  else
    Result := False;
end;

function TPdfPage.FindPrev(var CharIndex, Count: Integer): Boolean;
begin
  CharIndex := 0;
  Count := 0;
  if FSearchHandle <> nil then
  begin
    Result := FPDFText_FindPrev(FSearchHandle) <> 0;
    if Result then
    begin
      CharIndex := FPDFText_GetSchResultIndex(FSearchHandle);
      Count := FPDFText_GetSchCount(FSearchHandle);
    end;
  end
  else
    Result := False;
end;

function TPdfPage.GetCharCount: Integer;
begin
  if BeginText then
    Result := FPDFText_CountChars(FTextHandle)
  else
    Result := 0;
end;

function TPdfPage.ReadChar(CharIndex: Integer): WideChar;
begin
  if BeginText then
    Result := FPDFText_GetUnicode(FTextHandle, CharIndex)
  else
    Result := #0;
end;

function TPdfPage.GetCharFontSize(CharIndex: Integer): Double;
begin
  if BeginText then
    Result := FPDFText_GetFontSize(FTextHandle, CharIndex)
  else
    Result := 0;
end;

function TPdfPage.GetCharBox(CharIndex: Integer): TPdfRect;
begin
  if BeginText then
    FPDFText_GetCharBox(FTextHandle, CharIndex, Result.Left, Result.Right, Result.Bottom, Result.Top)
  else
    Result := TPdfRect.Empty;
end;

function TPdfPage.GetCharIndexAt(PageX, PageY, ToleranceX, ToleranceY: Double): Integer;
begin
  if BeginText then
    Result := FPDFText_GetCharIndexAtPos(FTextHandle, PageX, PageY, ToleranceX, ToleranceY)
  else
    Result := 0;
end;

function TPdfPage.ReadText(CharIndex, Count: Integer): string;
var
  Len: Integer;
  p : TBytes;
begin
  if (Count > 0) and BeginText then
  begin
    SetLength(p, (Count+1)*2); // we let GetText overwrite our #0 terminator with its #0
    Len := FPDFText_GetText(FTextHandle, CharIndex, Count, p)-1; // returned length includes the #0
    if Len <= 0 then
      Result := ''
    else if Len <= Count then
    begin
      result := TEncoding.Unicode.GetString(p);
      if result[length(result)] = #0 then
        delete(result, length(result), 1);
    end;
  end
  else
    Result := '';
end;

function TPdfPage.GetTextAt(Left, Top, Right, Bottom: Double): WideString;
var
  Len: Integer;
begin
  if BeginText then
  begin
    Len := FPDFText_GetBoundedText(FTextHandle, Left, Top, Right, Bottom, nil, 0); // excluding #0 terminator
    SetLength(Result, Len);
    if Len > 0 then
      FPDFText_GetBoundedText(FTextHandle, Left, Top, Right, Bottom, PWideChar(Result), Len);
  end
  else
    Result := '';
end;

function TPdfPage.GetTextAt(const R: TPdfRect): string;
begin
  Result := GetTextAt(R.Left, R.Top, R.Right, R.Bottom);
end;

function TPdfPage.GetTextRectCount(CharIndex, Count: Integer): Integer;
begin
  if BeginText then
    Result := FPDFText_CountRects(FTextHandle, CharIndex, Count)
  else
    Result := 0;
end;

function TPdfPage.GetTextRect(RectIndex: Integer): TPdfRect;
begin
  if BeginText then
    FPDFText_GetRect(FTextHandle, RectIndex, Result.Left, Result.Top, Result.Right, Result.Bottom)
  else
    Result := TPdfRect.Empty;
end;

function TPdfPage.GetWebLinkCount: Integer;
begin
  if BeginWebLinks then
  begin
    Result := FPDFLink_CountWebLinks(FLinkHandle);
    if Result < 0 then
      Result := 0;
  end
  else
    Result := 0;
end;

function TPdfPage.GetWebLinkURL(LinkIndex: Integer): WideString;
var
  Len: Integer;
begin
  Result := '';
  if BeginWebLinks then
  begin
    Len := FPDFLink_GetURL(FLinkHandle, LinkIndex, nil, 0) - 1; // including #0 terminator
    if Len > 0 then
    begin
      SetLength(Result, Len);
      FPDFLink_GetURL(FLinkHandle, LinkIndex, PWideChar(Result), Len + 1); // including #0 terminator
    end;
  end;
end;

function TPdfPage.GetWebLinkRectCount(LinkIndex: Integer): Integer;
begin
  if BeginWebLinks then
    Result := FPDFLink_CountRects(FLinkHandle, LinkIndex)
  else
    Result := 0;
end;

function TPdfPage.GetWebLinkRect(LinkIndex, RectIndex: Integer): TPdfRect;
begin
  if BeginWebLinks then
    FPDFLink_GetRect(FLinkHandle, LinkIndex, RectIndex, Result.Left, Result.Top, Result.Right, Result.Bottom)
  else
    Result := TPdfRect.Empty;
end;

function TPdfPage.GetMouseModifier(const Shift: TShiftState): Integer;
begin
  Result := 0;
  if ssShift in Shift then
    Result := Result or FWL_EVENTFLAG_ShiftKey;
  if ssCtrl in Shift then
    Result := Result or FWL_EVENTFLAG_ControlKey;
  if ssAlt in Shift then
    Result := Result or FWL_EVENTFLAG_AltKey;
  if ssLeft in Shift then
    Result := Result or FWL_EVENTFLAG_LeftButtonDown;
  if ssMiddle in Shift then
    Result := Result or FWL_EVENTFLAG_MiddleButtonDown;
  if ssRight in Shift then
    Result := Result or FWL_EVENTFLAG_RightButtonDown;
end;

function TPdfPage.GetKeyModifier(KeyData: LPARAM): Integer;
const
  AltMask = $20000000;
begin
  Result := 0;
  {$IFDEF MSWINDOWS}
  if GetKeyState(VK_SHIFT) < 0 then
    Result := Result or FWL_EVENTFLAG_ShiftKey;
  if GetKeyState(VK_CONTROL) < 0 then
    Result := Result or FWL_EVENTFLAG_ControlKey;
  if KeyData and AltMask <> 0 then
    Result := Result or FWL_EVENTFLAG_AltKey;
  {$ENDIF}
end;

function TPdfPage.FormEventFocus(const Shift: TShiftState; PageX, PageY: Double): Boolean;
begin
  if IsValidForm then
    Result := FORM_OnFocus(FDocument.FForm, FPage, GetMouseModifier(Shift), PageX, PageY) <> 0
  else
    Result := False;
end;

function TPdfPage.FormEventMouseWheel(const Shift: TShiftState; WheelDelta: Integer; PageX, PageY: Double): Boolean;
var
  Pt: TFSPointF;
  WheelX, WheelY: Integer;
begin
  if IsValidForm then
  begin
    Pt.X := PageX;
    Pt.Y := PageY;
    WheelX := 0;
    WheelY := 0;
    if ssShift in Shift then
      WheelX := WheelDelta
    else
      WheelY := WheelDelta;
    Result := FORM_OnMouseWheel(FDocument.FForm, FPage, GetMouseModifier(Shift), @Pt, WheelX, WheelY) <> 0;
  end
  else
    Result := False;
end;

function TPdfPage.FormEventMouseMove(const Shift: TShiftState; PageX, PageY: Double): Boolean;
begin
  if IsValidForm then
    Result := FORM_OnMouseMove(FDocument.FForm, FPage, GetMouseModifier(Shift), PageX, PageY) <> 0
  else
    Result := False;
end;

function TPdfPage.FormEventLButtonDown(const Shift: TShiftState; PageX, PageY: Double): Boolean;
begin
  if IsValidForm then
    Result := FORM_OnLButtonDown(FDocument.FForm, FPage, GetMouseModifier(Shift), PageX, PageY) <> 0
  else
    Result := False;
end;

function TPdfPage.FormEventLButtonUp(const Shift: TShiftState; PageX, PageY: Double): Boolean;
begin
  if IsValidForm then
    Result := FORM_OnLButtonUp(FDocument.FForm, FPage, GetMouseModifier(Shift), PageX, PageY) <> 0
  else
    Result := False;
end;

function TPdfPage.FormEventRButtonDown(const Shift: TShiftState; PageX, PageY: Double): Boolean;
begin
  if IsValidForm then
    Result := FORM_OnRButtonDown(FDocument.FForm, FPage, GetMouseModifier(Shift), PageX, PageY) <> 0
  else
    Result := False;
end;

function TPdfPage.FormEventRButtonUp(const Shift: TShiftState; PageX, PageY: Double): Boolean;
begin
  if IsValidForm then
    Result := FORM_OnRButtonUp(FDocument.FForm, FPage, GetMouseModifier(Shift), PageX, PageY) <> 0
  else
    Result := False;
end;

function TPdfPage.FormEventKeyDown(KeyCode: Word; KeyData: LPARAM): Boolean;
begin
  if IsValidForm then
    Result := FORM_OnKeyDown(FDocument.FForm, FPage, KeyCode, GetKeyModifier(KeyData)) <> 0
  else
    Result := False;
end;

function TPdfPage.FormEventKeyUp(KeyCode: Word; KeyData: LPARAM): Boolean;
begin
  if IsValidForm then
    Result := FORM_OnKeyUp(FDocument.FForm, FPage, KeyCode, GetKeyModifier(KeyData)) <> 0
  else
    Result := False;
end;

function TPdfPage.FormEventKeyPress(Key: Word; KeyData: LPARAM): Boolean;
begin
  if IsValidForm then
    Result := FORM_OnChar(FDocument.FForm, FPage, Key, GetKeyModifier(KeyData)) <> 0
  else
    Result := False;
end;

function TPdfPage.FormEventKillFocus: Boolean;
begin
  if IsValidForm then
    Result := FORM_ForceToKillFocus(FDocument.FForm) <> 0
  else
    Result := False;
end;

function TPdfPage.FormGetFocusedText: string;
var
  ByteLen: LongWord;
begin
  if IsValidForm then
  begin
    ByteLen := FORM_GetFocusedText(FDocument.FForm, FPage, nil, 0); // UTF 16 including #0 terminator in byte size
    if ByteLen <= 2 then // WideChar(#0) => empty string
      Result := ''
    else
    begin
      SetLength(Result, ByteLen div SizeOf(WideChar) - 1);
      FORM_GetFocusedText(FDocument.FForm, FPage, PWideChar(Result), ByteLen);
    end;
  end
  else
    Result := '';
end;

function TPdfPage.FormGetSelectedText: string;
var
  ByteLen: LongWord;
begin
  if IsValidForm then
  begin
    ByteLen := FORM_GetSelectedText(FDocument.FForm, FPage, nil, 0); // UTF 16 including #0 terminator in byte size
    if ByteLen <= 2 then // WideChar(#0) => empty string
      Result := ''
    else
    begin
      SetLength(Result, ByteLen div SizeOf(WideChar) - 1);
      FORM_GetSelectedText(FDocument.FForm, FPage, PWideChar(Result), ByteLen);
    end;
  end
  else
    Result := '';
end;

function TPdfPage.FormReplaceSelection(const ANewText: string): Boolean;
begin
  if IsValidForm then
  begin
    FORM_ReplaceSelection(FDocument.FForm, FPage, PWideChar(ANewText));
    Result := True;
  end
  else
    Result := False;
end;

function TPdfPage.FormSelectAllText: Boolean;
begin
  if IsValidForm then
    Result := FORM_SelectAllText(FDocument.FForm, FPage) <> 0
  else
    Result := False;
end;

function TPdfPage.FormCanUndo: Boolean;
begin
  if IsValidForm then
    Result := FORM_CanUndo(FDocument.FForm, FPage) <> 0
  else
    Result := False;
end;

function TPdfPage.FormCanRedo: Boolean;
begin
  if IsValidForm then
    Result := FORM_CanRedo(FDocument.FForm, FPage) <> 0
  else
    Result := False;
end;

function TPdfPage.FormUndo: Boolean;
begin
  if IsValidForm then
    Result := FORM_Undo(FDocument.FForm, FPage) <> 0
  else
    Result := False;
end;

function TPdfPage.FormRedo: Boolean;
begin
  if IsValidForm then
    Result := FORM_Redo(FDocument.FForm, FPage) <> 0
  else
    Result := False;
end;

function TPdfPage.HasFormFieldAtPoint(X, Y: Double): TPdfFormFieldType;
begin
  case FPDFPage_HasFormFieldAtPoint(FDocument.FForm, FPage, X, Y) of
    FPDF_FORMFIELD_PUSHBUTTON:
      Result := fftPushButton;
    FPDF_FORMFIELD_CHECKBOX:
      Result := fftCheckBox;
    FPDF_FORMFIELD_RADIOBUTTON:
      Result := fftRadioButton;
    FPDF_FORMFIELD_COMBOBOX:
      Result := fftComboBox;
    FPDF_FORMFIELD_LISTBOX:
      Result := fftListBox;
    FPDF_FORMFIELD_TEXTFIELD:
      Result := fftTextField;
    FPDF_FORMFIELD_SIGNATURE:
      Result := fftSignature;
  else
    Result := fftUnknown;
  end;
end;

function TPdfPage.GetHandle: FPDF_PAGE;
begin
  Open;
  Result := FPage;
end;

function TPdfPage.IsLoaded: Boolean;
begin
  Result := FPage <> nil;
end;

procedure TPdfPage.Draw(bitmap : TBitmap; Rotate: TPdfPageRotation; const Options: TPdfPageRenderOptions);
var
  PdfBmp: TPdfBitmap;
  BitmapInfo: TBitmapInfo;
  Bmp, OldBmp: HBITMAP;
  BmpBits: Pointer;
  BmpDC: HDC;
  vbmp : TBitmap;
begin
  Open;

  {$IFDEF NON_DC_DRAWING}
  PdfBmp := TPdfBitmap.Create(bitmap.Width, bitmap.Height, bfBGRA, BmpBits, bitmap.Width * 4);
  try
    if Transparency then
      PdfBmp.FillRect(0, 0, bitmap.Width, bitmap.Height, $00FFFFFF)
    else
      PdfBmp.FillRect(0, 0, bitmap.Width, bitmap.Height, $FFFFFFFF);
    DrawToPdfBitmap(PdfBmp, 0, 0, bitmap.Width, bitmap.Height, Rotate, Options);
    DrawFormToPdfBitmap(PdfBmp, 0, 0, bitmap.Width, bitmap.Height, Rotate, Options);
    PdfBmp.toBitmap(bitmap);
  finally
    PdfBmp.Free;
  end;
  {$ELSE}
  FillChar(BitmapInfo, SizeOf(BitmapInfo), 0);
  BitmapInfo.bmiHeader.biSize := SizeOf(BitmapInfo);
  BitmapInfo.bmiHeader.biWidth := bitmap.Width;
  BitmapInfo.bmiHeader.biHeight := -bitmap.Height;
  BitmapInfo.bmiHeader.biPlanes := 1;
  BitmapInfo.bmiHeader.biBitCount := 32;
  BitmapInfo.bmiHeader.biCompression := BI_RGB;
  BmpBits := nil;
  Bmp := CreateDIBSection(bitmap.Canvas.handle, BitmapInfo, DIB_RGB_COLORS, BmpBits, 0, 0);
  if Bmp <> 0 then
  begin
    PdfBmp := TPdfBitmap.Create(bitmap.Width, bitmap.Height, bfBGRA, BmpBits, bitmap.Width * 4);
    try
      if Transparency then
        PdfBmp.FillRect(0, 0, bitmap.Width, bitmap.Height, $00FFFFFF)
      else
        PdfBmp.FillRect(0, 0, bitmap.Width, bitmap.Height, $FFFFFFFF);
      DrawToPdfBitmap(PdfBmp, 0, 0, bitmap.Width, bitmap.Height, Rotate, Options);
      DrawFormToPdfBitmap(PdfBmp, 0, 0, bitmap.Width, bitmap.Height, Rotate, Options);
    finally
      PdfBmp.Free;
    end;
    try

      vbmp := TBitmap.Create;
      try
        vbmp.Handle := bmp;
        bitmap.assign(vbmp);
        bitmap.Canvas.Handle; // ake sure the copy actually happens.
      finally
        vbmp.Free;
      end;
    finally
      DeleteObject(Bmp);
    end;
  end;
  {$ENDIF}
end;

{ _TPdfBitmapHideCtor }

procedure _TPdfBitmapHideCtor.Create;
begin
  inherited Create;
end;

{ TPdfBitmap }

constructor TPdfBitmap.Create(ABitmap: FPDF_BITMAP; AOwnsBitmap: Boolean);
begin
  inherited Create;
  FBitmap := ABitmap;
  FOwnsBitmap := AOwnsBitmap;
  if FBitmap <> nil then
  begin
    FWidth := FPDFBitmap_GetWidth(FBitmap);
    FHeight := FPDFBitmap_GetHeight(FBitmap);
    FBytesPerScanLine := FPDFBitmap_GetStride(FBitmap);
  end;
end;

constructor TPdfBitmap.Create(AWidth, AHeight: Integer; AAlpha: Boolean);
begin
  Create(FPDFBitmap_Create(AWidth, AHeight, Ord(AAlpha)), True);
end;

constructor TPdfBitmap.Create(AWidth, AHeight: Integer; AFormat: TPdfBitmapFormat);
begin
  Create(FPDFBitmap_CreateEx(AWidth, AHeight, Ord(AFormat), nil, 0), True);
end;

constructor TPdfBitmap.Create(AWidth, AHeight: Integer;
  AFormat: TPdfBitmapFormat; ABuffer: Pointer; ABytesPerScanline: Integer);
begin
  Create(FPDFBitmap_CreateEx(AWidth, AHeight, Ord(AFormat), ABuffer, ABytesPerScanline), True);
end;

destructor TPdfBitmap.Destroy;
begin
  if FOwnsBitmap and (FBitmap <> nil) then
    FPDFBitmap_Destroy(FBitmap);
  inherited Destroy;
end;

function TPdfBitmap.GetBuffer: Pointer;
begin
  if FBitmap <> nil then
    Result := FPDFBitmap_GetBuffer(FBitmap)
  else
    Result := nil;
end;

type
  TRGBTripleArray = ARRAY[Word] of TRGBTriple;
  pRGBTripleArray = ^TRGBTripleArray; // Use a PByteArray for pf8bit color.

function TPdfBitmap.toBitmap: TBitmap;
begin
  result := TBitmap.Create;
  try
    toBitmap(result);
  except
    result.Free;
    raise;
  end;
end;

procedure TPdfBitmap.toBitmap(bmp: TBitmap);
var
  fmt : Integer;
  p : pByte;
  pt, pl : pByte;
  w, wt, h, ht, stride: Integer;
  r,g,b : byte;
begin
  fmt := FPDFBitmap_GetFormat(FBitmap);
  wt := FPDFBitmap_GetWidth(FBitmap);
  bmp.Width := wt;
  ht := FPDFBitmap_GetHeight(FBitmap);
  bmp.Height := ht;
  stride := FPDFBitmap_GetStride(FBitmap);
  p := FPDFBitmap_GetBuffer(FBitmap);
  case fmt of
    FPDFBitmap_BGR :
    begin
      bmp.PixelFormat := pf24bit;
      // 3 bytes per pixel, byte order: blue, green, red.
      for h := 0 to ht - 1 do
      begin
        pt := p;
        pl := bmp.ScanLine[h];
        // same format
        move(pt^, pl^, wt * 3);
        inc(p, stride);
      end;
    end;
    FPDFBitmap_BGRA :
    begin
    // 4 bytes per pixel, byte order: blue, green, red, alpha
      bmp.PixelFormat := pf32bit;
      for h := 0 to ht - 1 do
      begin
        pt := p;
        pl := bmp.ScanLine[h];
        // same format
        move(pt^, pl^, wt * 4);
        inc(p, stride);
      end;
    end;
    FPDFBitmap_Gray :
    begin
      // 1 bytes per pixel, byte order: grey.
      bmp.PixelFormat := pf24bit;
      for h := 0 to bmp.Height - 1 do
      begin
        pt := p;
        pl := bmp.ScanLine[h];
        for w := 0 to wt - 1 do
        begin
          b := pt^;
          inc(pt);
          pl^ := b;
          inc(pl);
          pl^ := b;
          inc(pl);
          pl^ := b;
          inc(pl);
        end;
        inc(p, stride);
      end;
    end;
    else
      raise Exception.Create('Format '+inttostr(fmt)+' not supported');
  end;
end;

procedure TPdfBitmap.FillRect(ALeft, ATop, AWidth, AHeight: Integer; AColor: FPDF_DWORD);
begin
  if FBitmap <> nil then
    FPDFBitmap_FillRect(FBitmap, ALeft, ATop, AWidth, AHeight, AColor);
end;

{ TPdfPoint }

procedure TPdfPoint.Offset(XOffset, YOffset: Double);
begin
  X := X + XOffset;
  Y := Y + YOffset;
end;

class function TPdfPoint.Empty: TPdfPoint;
begin
  Result.X := 0;
  Result.Y := 0;
end;

{ TPdfAttachmentList }

constructor TPdfAttachmentList.Create(ADocument: TPdfDocument);
begin
  inherited Create;
  FDocument := ADocument;
end;

function TPdfAttachmentList.GetCount: Integer;
begin
  FDocument.CheckActive;
  Result := FPDFDoc_GetAttachmentCount(FDocument.Handle);
end;

function TPdfAttachmentList.GetItem(Index: Integer): TPdfAttachment;
var
  Attachment: FPDF_ATTACHMENT;
begin
  FDocument.CheckActive;
  Attachment := FPDFDoc_GetAttachment(FDocument.Handle, Index);
  if Attachment = nil then
    raise EPdfArgumentOutOfRange.CreateResFmt(@RsArgumentsOutOfRange, ['Index']);
  Result.FDocument := FDocument;
  Result.FHandle := Attachment;
end;

procedure TPdfAttachmentList.Delete(Index: Integer);
begin
  FDocument.CheckActive;
  if FPDFDoc_DeleteAttachment(FDocument.Handle, Index) = 0 then
    raise EPdfException.CreateResFmt(@RsPdfCannotDeleteAttachmnent, [Index]);
end;

function TPdfAttachmentList.Add(const Name: string): TPdfAttachment;
begin
  FDocument.CheckActive;
  Result.FDocument := FDocument;
  Result.FHandle := FPDFDoc_AddAttachment(FDocument.Handle, PWideChar(Name));
  if Result.FHandle = nil then
    raise EPdfException.CreateResFmt(@RsPdfCannotAddAttachmnent, [Name]);
end;

{ TPdfAttachment }

function TPdfAttachment.GetName: string;
var
  ByteLen: LongWord;
begin
  CheckValid;
  ByteLen := FPDFAttachment_GetName(Handle, nil, 0); // UTF 16 including #0 terminator in byte size
  if ByteLen <= 2 then
    Result := ''
  else
  begin
    SetLength(Result, ByteLen div SizeOf(WideChar) - 1);
    FPDFAttachment_GetName(FHandle, PWideChar(Result), ByteLen);
  end;
end;

procedure TPdfAttachment.CheckValid;
begin
  if FDocument <> nil then
    FDocument.CheckActive;
end;

procedure TPdfAttachment.SetContent(ABytes: PByte; Count: Integer);
begin
  CheckValid;
  if FPDFAttachment_SetFile(FHandle, FDocument.Handle, ABytes, Count) = 0 then
    raise EPdfException.CreateResFmt(@RsPdfCannotSetAttachmentContent, [Name]);
end;

procedure TPdfAttachment.SetContent(const Value: RawByteString);
begin
  if Value = '' then
    SetContent(nil, 0)
  else
    SetContent(PByte(PAnsiChar(Value)), Length(Value) * SizeOf(AnsiChar));
end;


procedure TPdfAttachment.SetContent(const Value: string; Encoding: TEncoding = nil);
begin
  CheckValid;
  if Value = '' then
    SetContent(nil, 0)
  else if (Encoding = nil) or (Encoding = TEncoding.UTF8) then
    SetContent(UTF8Encode(Value))
  else
    SetContent(Encoding.GetBytes(Value));
end;

procedure TPdfAttachment.SetContent(const ABytes: TBytes; Index: NativeInt; Count: Integer);
var
  Len: NativeInt;
begin
  CheckValid;

  Len := Length(ABytes);
  if Index >= Len then
    raise EPdfArgumentOutOfRange.CreateResFmt(@RsArgumentsOutOfRange, ['Index', Index]);
  if Index + Count > Len then
    raise EPdfArgumentOutOfRange.CreateResFmt(@RsArgumentsOutOfRange, ['Count', Count]);

  if Count = 0 then
    SetContent(nil, 0)
  else
    SetContent(@ABytes[Index], Count);
end;

procedure TPdfAttachment.SetContent(const ABytes: TBytes);
begin
  SetContent(ABytes, 0, Length(ABytes));
end;

procedure TPdfAttachment.LoadFromStream(Stream: TStream);
var
  StreamPos, StreamSize: Int64;
  Buf: PByte;
  Count: Integer;
begin
  CheckValid;

  StreamPos := Stream.Position;
  StreamSize := Stream.Size;
  Count := StreamSize - StreamPos;
  if Count = 0 then
    SetContent(nil, 0)
  else
  begin
    if Stream is TCustomMemoryStream then // direct access to the memory
    begin
      SetContent(PByte(TCustomMemoryStream(Stream).Memory) + StreamPos, Count);
      Stream.Position := StreamSize; // simulate the ReadBuffer call
    end
    else
    begin
      if Count = 0 then
        SetContent(nil, 0)
      else
      begin
        GetMem(Buf, Count);
        try
          Stream.ReadBuffer(Buf^, Count);
          SetContent(Buf, Count);
        finally
          FreeMem(Buf);
        end;
      end;
    end;
  end;
end;

procedure TPdfAttachment.LoadFromFile(const FileName: string);
var
  Stream: TFileStream;
begin
  CheckValid;

  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    LoadFromStream(Stream);
  finally
    Stream.Free;
  end;
end;

function TPdfAttachment.HasKey(const Key: string): Boolean;
begin
  CheckValid;
  Result := FPDFAttachment_HasKey(FHandle, PAnsiChar(UTF8Encode(Key))) <> 0;
end;

function TPdfAttachment.GetValueType(const Key: string): TPdfObjectType;
begin
  CheckValid;
  Result := TPdfObjectType(FPDFAttachment_GetValueType(FHandle, PAnsiChar(UTF8Encode(Key))));
end;

procedure TPdfAttachment.SetKeyValue(const Key, Value: string);
begin
  CheckValid;
  if FPDFAttachment_SetStringValue(FHandle, PAnsiChar(UTF8Encode(Key)), PWideChar(Value)) = 0 then
    raise EPdfException.CreateRes(@RsPdfAttachmentContentNotSet);
end;

function TPdfAttachment.GetKeyValue(const Key: string): string;
var
  ByteLen: LongWord;
  Utf8Key: UTF8String;
begin
  CheckValid;
  Utf8Key := UTF8Encode(Key);
  ByteLen := FPDFAttachment_GetStringValue(FHandle, PAnsiChar(Utf8Key), nil, 0);
  if ByteLen = 0 then
    raise EPdfException.CreateRes(@RsPdfAttachmentContentNotSet);

  if ByteLen <= 2 then
    Result := ''
  else
  begin
    SetLength(Result, (ByteLen div SizeOf(WideChar) - 1));
    FPDFAttachment_GetStringValue(FHandle, PAnsiChar(Utf8Key), PWideChar(Result), ByteLen);
  end;
end;

function TPdfAttachment.GetContentSize: Integer;
var
  OutBufLen: LongWord;
begin
  CheckValid;
  if FPDFAttachment_GetFile(FHandle, nil, 0, OutBufLen) = 0 then
    Result := 0
  else
    Result := Integer(OutBufLen);
end;

function TPdfAttachment.HasContent: Boolean;
var
  OutBufLen: LongWord;
begin
  CheckValid;
  Result := FPDFAttachment_GetFile(FHandle, nil, 0, OutBufLen) <> 0;
end;

procedure TPdfAttachment.SaveToFile(const FileName: string);
var
  Stream: TStream;
begin
  CheckValid;

  Stream := TFileStream.Create(FileName, fmCreate or fmShareDenyWrite);
  try
    SaveToStream(Stream);
  finally
    Stream.Free;
  end;
end;

procedure TPdfAttachment.SaveToStream(Stream: TStream);
var
  Size: Integer;
  OutBufLen: LongWord;
  StreamPos: Int64;
  Buf: PByte;
begin
  Size := ContentSize;

  if Size > 0 then
  begin
    if Stream is TCustomMemoryStream then // direct access to the memory
    begin
      StreamPos := Stream.Position;
      if StreamPos + Size > Stream.Size then
        Stream.Size := StreamPos + Size; // allocate enough memory
      Stream.Position := StreamPos;

      FPDFAttachment_GetFile(FHandle, PByte(TCustomMemoryStream(Stream).Memory) + StreamPos, Size, OutBufLen);
      Stream.Position := StreamPos + Size; // simulate Stream.WriteBuffer
    end
    else
    begin
      GetMem(Buf, Size);
      try
        FPDFAttachment_GetFile(FHandle, Buf, Size, OutBufLen);
        Stream.WriteBuffer(Buf^, Size);
      finally
        FreeMem(Buf);
      end;
    end;
  end;
end;

procedure TPdfAttachment.GetContent(var Value: WideString; Encoding: TEncoding);
var
  Size: Integer;
  OutBufLen: LongWord;
  Buf: PByte;
begin
  Size := ContentSize;
  if Size <= 0 then
    Value := ''
  else if Encoding = TEncoding.Unicode then // no conversion needed
  begin
    SetLength(Value, Size div SizeOf(WideChar));
    FPDFAttachment_GetFile(FHandle, PWideChar(Value), Size, OutBufLen);
  end
  else
  begin
    if Encoding = nil then
      Encoding := TEncoding.UTF8;

    GetMem(Buf, Size);
    try
      FPDFAttachment_GetFile(FHandle, Buf, Size, OutBufLen);
      SetLength(Value, TEncodingAccess(Encoding).GetMemCharCount(Buf, Size));
      if Value <> '' then
        TEncodingAccess(Encoding).GetMemChars(Buf, Size, PWideChar(Value), Length(Value));
    finally
      FreeMem(Buf);
    end;
  end;
end;

procedure TPdfAttachment.GetContent(var Value: RawByteString);
var
  Size: Integer;
  OutBufLen: LongWord;
begin
  Size := ContentSize;

  if Size <= 0 then
    Value := ''
  else
  begin
    SetLength(Value, Size);
    FPDFAttachment_GetFile(FHandle, PAnsiChar(Value), Size, OutBufLen);
  end;
end;

procedure TPdfAttachment.GetContent(Buffer: PByte);
var
  OutBufLen: LongWord;
begin
  FPDFAttachment_GetFile(FHandle, Buffer, ContentSize, OutBufLen);
end;

procedure TPdfAttachment.GetContent(var ABytes: TBytes);
var
  Size: Integer;
  OutBufLen: LongWord;
begin
  Size := ContentSize;

  if Size <= 0 then
    ABytes := nil
  else
  begin
    SetLength(ABytes, Size);
    FPDFAttachment_GetFile(FHandle, @ABytes[0], Size, OutBufLen);
  end;
end;

function TPdfAttachment.GetContentAsBytes: TBytes;
begin
  GetContent(Result);
end;

function TPdfAttachment.GetContentAsRawByteString: RawByteString;
begin
  GetContent(Result);
end;

function TPdfAttachment.GetContentAsString(Encoding: TEncoding): WideString;
begin
  GetContent(Result, Encoding);
end;

{ TPdfDocumentPrinter }

constructor TPdfDocumentPrinter.Create;
begin
  inherited Create;
  FPrintTextWithGDI := False;
  FFitPageToPrintArea := True;
end;

function TPdfDocumentPrinter.IsPortraitOrientation(AWidth, AHeight: Integer): Boolean;
begin
  Result := AHeight > AWidth;
end;

{$IFDEF MSWINDOWS}
procedure TPdfDocumentPrinter.GetPrinterBounds;
begin
  FPaperSize.cx := GetDeviceCaps(FPrinterDC, PHYSICALWIDTH);
  FPaperSize.cy := GetDeviceCaps(FPrinterDC, PHYSICALHEIGHT);

  FPrintArea.cx := GetDeviceCaps(FPrinterDC, HORZRES);
  FPrintArea.cy := GetDeviceCaps(FPrinterDC, VERTRES);

  FMargins.X := GetDeviceCaps(FPrinterDC, PHYSICALOFFSETX);
  FMargins.Y := GetDeviceCaps(FPrinterDC, PHYSICALOFFSETY);
end;

function TPdfDocumentPrinter.BeginPrint(const AJobTitle: string): Boolean;
begin
  Inc(FBeginPrintCounter);
  if FBeginPrintCounter = 1 then
  begin
    Result := PrinterStartDoc(AJobTitle);
    if Result then
    begin
      FPrinterDC := GetPrinterDC;

      GetPrinterBounds;
      FPrintPortraitOrientation := IsPortraitOrientation(FPaperSize.cx, FPaperSize.cy);
    end
    else
    begin
      FPrinterDC := 0;
      Dec(FBeginPrintCounter);
    end;
  end
  else
    Result := True;
end;

procedure TPdfDocumentPrinter.EndPrint;
begin
  Dec(FBeginPrintCounter);
  if FBeginPrintCounter = 0 then
  begin
    if FPrinterDC <> 0 then
    begin
      FPrinterDC := 0;
      PrinterEndDoc;
    end;
  end;
end;

function TPdfDocumentPrinter.Print(ADocument: TPdfDocument): Boolean;
begin
  if ADocument <> nil then
    Result := Print(ADocument, 0, ADocument.PageCount - 1)
  else
    Result := False;
end;

function TPdfDocumentPrinter.Print(ADocument: TPdfDocument; AFromPageIndex, AToPageIndex: Integer): Boolean;
var
  PageIndex: Integer;
  WasPageLoaded: Boolean;
  PdfPage: TPdfPage;
  PagePortraitOrientation: Boolean;
  X, Y, W, H: Integer;
  PrintedPageNum, PrintPageCount: Integer;
begin
  Result := False;
  if ADocument = nil then
    Exit;

  if AFromPageIndex < 0 then
    raise EPdfArgumentOutOfRange.CreateResFmt(@RsArgumentsOutOfRange, ['FromPage', AFromPageIndex]);
  if (AToPageIndex < AFromPageIndex) or (AToPageIndex >= ADocument.PageCount) then
    raise EPdfArgumentOutOfRange.CreateResFmt(@RsArgumentsOutOfRange, ['ToPage', AToPageIndex]);

  PrintedPageNum := 0;
  PrintPageCount := AToPageIndex - AFromPageIndex + 1;

  if BeginPrint then
  begin
    try
      if ADocument.FForm <> nil then
        FORM_DoDocumentAAction(ADocument.FForm, FPDFDOC_AACTION_WP); // BeforePrint

      for PageIndex := AFromPageIndex to AToPageIndex do
      begin
        PdfPage := nil;
        WasPageLoaded := ADocument.IsPageLoaded(PageIndex);
        try
          PdfPage := ADocument.Pages[PageIndex];
          PagePortraitOrientation := IsPortraitOrientation(Trunc(PdfPage.Width), Trunc(PdfPage.Height));

          if FitPageToPrintArea then
          begin
            X := 0;
            Y := 0;
            W := FPrintArea.cx;
            H := FPrintArea.cy;
          end
          else
          begin
            X := -FMargins.X;
            Y := -FMargins.Y;
            W := FPaperSize.cx;
            H := FPaperSize.cy;
          end;

          if PagePortraitOrientation <> FPrintPortraitOrientation then
          begin
            SwapInts(X, Y);
            SwapInts(W, H);
          end;

          // Print page
          PrinterStartPage;
          try
            if (W > 0) and (H > 0) then
              InternPrintPage(PdfPage, X, Y, W, H);
          finally
            PrinterEndPage;
          end;
          Inc(PrintedPageNum);
          if Assigned(OnPrintStatus) then
            OnPrintStatus(Self, PrintedPageNum, PrintPageCount);
        finally
          if not WasPageLoaded and (PdfPage <> nil) then
            PdfPage.Close; // release memory
        end;
        if ADocument.FForm <> nil then
          FORM_DoDocumentAAction(ADocument.FForm, FPDFDOC_AACTION_DP); // AfterPrint
      end;
    finally
      EndPrint;
    end;
    Result := True;
  end;
end;

procedure TPdfDocumentPrinter.InternPrintPage(APage: TPdfPage; X, Y, Width, Height: Double);

  function RoundToInt(Value: Double): Integer;
  var
    F: Double;
  begin
    Result := Trunc(Value);
    F := Frac(Value);
    if F < 0 then
    begin
      if F <= -0.5 then
        Result := Result - 1;
    end
    else if F >= 0.5 then
      Result := Result + 1;
  end;

var
  PageWidth, PageHeight: Double;
  PageScale, PrintScale: Double;
  ScaledWidth, ScaledHeight: Double;
  OldPrintTextWithGDI: Boolean;
begin
  PageWidth := APage.Width;
  PageHeight := APage.Height;

  PageScale := PageHeight / PageWidth;
  PrintScale := Height / Width;

  ScaledWidth := Width;
  ScaledHeight := Height;
  if PageScale > PrintScale then
    ScaledWidth := Width * (PrintScale / PageScale)
  else
    ScaledHeight := Height * (PageScale / PrintScale);

  X := X + (Width - ScaledWidth) / 2;
  Y := Y + (Height - ScaledHeight) / 2;

  // PrintTextWithGDI is a global setting in PDFium so we set it only temporary and restore it after
  // printing the page.
  OldPrintTextWithGDI := TPdfDocument.SetPrintTextWithGDI(FPrintTextWithGDI);
  try
    APage.Draw(
      FPrinterDC,
      RoundToInt(X), RoundToInt(Y), RoundToInt(ScaledWidth), RoundToInt(ScaledHeight),
      prNormal, [proPrinting, proAnnotations]
    );
  finally
    if OldPrintTextWithGDI <> FPrintTextWithGDI then
      TPdfDocument.SetPrintTextWithGDI(OldPrintTextWithGDI);
  end;
end;
{$ENDIF}

{ TPDFObject }

function TPDFObject.AsBitmap: TBitmap;
var
  pdfBmp : TPdfBitmap;
begin
  pdfBmp := TPdfBitmap.Create(FPDFImageObj_GetBitmap(FHandle), true);
  try
    result := pdfBmp.toBitmap;
  finally
    pdfBmp.free;
  end;
end;

constructor TPDFObject.Create(Handle: FPDF_PAGEOBJECT; TextHandle: FPDF_TEXTPAGE);
begin
  inherited Create;
  FHandle := Handle;
  FTextHandle := TextHandle;
end;

function TPDFObject.GetKind: TPdfObjectKind;
begin
  result := TPdfObjectKind(FPDFPageObj_GetType(FHandle));
end;

function TPDFObject.GetText: String;
var
  i, l : integer;
  p : TBytes;
begin
  if kind = potText then
  begin
    l := FPDFTextObj_GetText(FHandle, FTextHandle, nil, 0);
    SetLength(p, l);
    l := FPDFTextObj_GetText(FHandle, FTextHandle, @p[0], l);
    result := TEncoding.Unicode.GetString(p);
    if result[length(result)] = #0 then
      delete(result, length(result), 1);
  end
  else
    result := '';
end;

initialization
  {$IFDEF MSWINDOWS}
  InitializeCriticalSectionAndSpinCount(PDFiumInitCritSect, 4000);
  InitializeCriticalSectionAndSpinCount(FFITimersCritSect, 4000);
  {$ELSE}
  InitCriticalSection(PDFiumInitCritSect);
  InitCriticalSection(FFITimersCritSect);
  {$ENDIF}

finalization
  {$IFDEF MSWINDOWS}
  DeleteCriticalSection(FFITimersCritSect);
  DeleteCriticalSection(PDFiumInitCritSect);
  {$ELSE}
  DoneCriticalSection(FFITimersCritSect);
  DoneCriticalSection(PDFiumInitCritSect);
  {$ENDIF}

end.
