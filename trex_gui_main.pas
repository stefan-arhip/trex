unit trex_gui_main;

{$mode objfpc}{$H+}

interface

uses
  SSockets, Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ShellCtrls,
  ExtCtrls, ComCtrls, StdCtrls, Spin, Menus, Buttons, IniPropStorage, MD5,
  StrUtils, Fileutil, LazFileUtils, TreeFilterEdit, ListViewFilterEdit,
  Dateutils, LCLVersion, Windows, Clipbrd;

const
  BUFSIZE = 8192;

  cmdUpdate = 0;
  cmdRetrieveDirectory = 1;
  cmdRetrieveFilelist = 2;
  cmdSendFiles = 3;
  cmdDeleteFiles = 4;
  cmdCreateDirectory = 5;
  cmdRenameDirectory = 6;
  cmdSizeDirectory = 7;
  cmdChecksumFiles = 8;

  icoUpFolder = 6;//4;
  icoFolder = 13;//7,4;
  icoFile = 8;//5;
  icoAdd = 9;
  icoEdit = 10;
  icoDelete = 11;
  icoComputer = 12;

  intOperationOk = 1;
  tabAboutIndex = 2;
  intColumnSize = 1;
  intColumnChecksum = 3;
  intColumnAddress = 4;

type

  { TfMain }

  TfMain = class(TForm)
    Bevel1: TBevel;
    Bevel2: TBevel;
    buItemRename: TBitBtn;
    buRetrieveDirectorySize: TBitBtn;
    buRetrieveFileChecksum: TBitBtn;
    buCreateNewFolder: TBitBtn;
    buSelectAll: TBitBtn;
    buUpdateClient: TBitBtn;
    buSendFiles: TBitBtn;
    buSelectionDelete: TBitBtn;
    buRetrieveFilelist: TBitBtn;
    cbRoot: TComboBox;
    cbFoldersSize: TCheckBox;
    cbFilesChecksum: TCheckBox;
    edRemoteSelectedFolder: TEdit;
    hcRemote: THeaderControl;
    hcRemoteEdit: THeaderControl;
    ilAnimation: TImageList;
    ilSmall: TImageList;
    Image1: TImage;
    IniPropStorage1: TIniPropStorage;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    laFPC: TLabel;
    laLazarus: TLabel;
    laTarget: TLabel;
    laUsername: TLabel;
    laVersion: TLabel;
    lbRemoteIP: TListBox;
    lbRemoteName: TListBox;
    lbRemotePort: TListBox;
    lfRemoteFiles: TListViewFilterEdit;
    lvRemoteFiles: TListView;
    lvRemoteDevices: TListView;
    miFilesGetChecksum: TMenuItem;
    miFolderGetSize: TMenuItem;
    miListSelectAll: TMenuItem;
    miLocaListCopyFilename: TMenuItem;
    miLocalListOpen: TMenuItem;
    miRemoteUpdate: TMenuItem;
    miLocalSendSelected: TMenuItem;
    miLocalListRefresh: TMenuItem;
    miSelectionDelete: TMenuItem;
    miListRefresh: TMenuItem;
    miItemRename: TMenuItem;
    miFolderCreate: TMenuItem;
    mmMain: TMainMenu;
    miTransfer: TMenuItem;
    miTransferCancel: TMenuItem;
    pcMain: TPageControl;
    Panel1: TPanel;
    Panel2: TPanel;
    pnDeviceOffline: TPanel;
    pmRemoteFiles: TPopupMenu;
    pmLocal: TPopupMenu;
    Separator1: TMenuItem;
    Separator2: TMenuItem;
    Separator3: TMenuItem;
    Separator4: TMenuItem;
    Separator5: TMenuItem;
    Splitter1: TSplitter;
    sbMain: TStatusBar;
    stLocal: TShellTreeView;
    tabDeviceList: TTabControl;
    tabWorkplace: TTabSheet;
    tabSettings: TTabSheet;
    tabAbout: TTabSheet;
    Timer1: TTimer;
    tfLocal: TTreeFilterEdit;
    procedure buSelectionDeleteClick(Sender: TObject);
    procedure buRetrieveFileChecksumClick(Sender: TObject);
    procedure buRetrieveDirectorySizeClick(Sender: TObject);
    procedure buSendFilesClick(Sender: TObject);
    procedure buRetrieveFilelistClick(Sender: TObject);
    procedure buUpdateClientClick(Sender: TObject);
    procedure cbRootEditingDone(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure hcRemoteEditSectionClick(HeaderControl: TCustomHeaderControl;
      Section: THeaderSection);
    procedure lvRemoteFilesDblClick(Sender: TObject);
    procedure lvRemoteFilesSelectItem(Sender: TObject; Item: TListItem;
      Selected: Boolean);
    procedure miFolderCreateClick(Sender: TObject);
    procedure miItemRenameClick(Sender: TObject);
    procedure miListSelectAllClick(Sender: TObject);
    procedure miLocaListCopyFilenameClick(Sender: TObject);
    procedure miLocalListOpenClick(Sender: TObject);
    procedure miLocalListRefreshClick(Sender: TObject);
    procedure miTransferCancelClick(Sender: TObject);
    procedure pcMainChange(Sender: TObject);
    procedure pmLocalPopup(Sender: TObject);
    procedure pmRemoteFilesPopup(Sender: TObject);
    procedure tabDeviceListChange(Sender: TObject);
    procedure tabDeviceListGetImageIndex(Sender: TObject; TabIndex: integer;
      var ImageIndex: integer);
    procedure Timer1Timer(Sender: TObject);
  private

  public

  end;

var
  fMain: TfMain;

implementation

{$R *.lfm}

uses trex_gui_device;

var
  Socket: TInetSocket;

  AnimationIndex: integer = 0;
  strRemoteName, strRemoteIP: string;
  intRemotePort: cardinal;

{ TfMain }

function FilesizeToCustomFormat(intFileSize: int64): string;
begin
  if intFileSize > 1024 * 1024 * 1024 then
    Result := Format('%.2f GB', [intFileSize / 1024 / 1024 / 1024])
  else if intFileSize > 1024 * 1024 then
    Result := Format('%.2f MB', [intFileSize / 1024 / 1024])
  else if intFileSize > 1024 then Result := Format('%.2f KB', [intFileSize / 1024])
  else
    Result := Format('%d', [intFileSize]);
end;

function SecondsToCustomFormat(LoadingTime: single): string;
begin
  if LoadingTime > 60 * 60 then
    Result := Format('%.2f hours', [LoadingTime / 60 / 60])
  else if LoadingTime > 60 then
    Result := Format('%.2f minutes', [LoadingTime / 60])
  else
    Result := Format('%.2f seconds', [LoadingTime]);
end;

function GetUserFromWindows: string;
var
  UserName: string = '';
  UserNameLen: dWord;
begin
  UserNameLen := 255;
  SetLength(UserName, UserNameLen);
  if Windows.GetUserName(PChar(UserName), UserNameLen) then
    Result := Copy(UserName, 1, UserNameLen - 1)
  else
    Result := 'Unknown';
end;

function SendFile(const strFolder, strFilename: string; Data: TInetSocket): boolean;
var
  fsContainer: TFileStream;
  Buffer: array[0..BUFSIZE - 1] of byte;
  BytesRead: integer;
  intFileSize, sendFileSize: int64;
  strChecksum, strCheck: string;
begin
  Result := False;
  Initialize(Buffer, Length(Buffer));
  if FileExists(strFolder + '\' + strFilename) then
  begin
    fsContainer := TFileStream.Create(strFolder + '\' + strFilename,
      fmOpenRead or fmShareDenyNone);
    try
      intFileSize := fsContainer.Size;
      strChecksum := MD5Print(MD5File(strFolder + '\' + strFilename, BUFSIZE));

      Data.WriteDWord(intFileSize);
      Data.WriteAnsiString(strChecksum);
      Data.WriteAnsiString(strFilename);

      sendFileSize := 0;
      repeat
        BytesRead := fsContainer.Read(Buffer, SizeOf(Buffer));
        Data.WriteBuffer(Buffer, BytesRead);
        Inc(sendFileSize, BytesRead);
      until sendFileSize >= intFileSize;

      strCheck := Data.ReadAnsiString;

      //showMessageFmt('%d'#13'%d', [sendFileSize, intFileSize]);
      //ShowMessage(strChecksum + ' - ' + strCheck);
      Result := strChecksum = strCheck;
    finally
      fsContainer.Free;
    end;
  end;
end;

function DeleteFile(const strFilename: string; Data: TInetSocket): boolean;
begin
  try
    Data.WriteByte(cmdDeleteFiles);
    Data.WriteAnsiString(strFilename);
    Result := Data.ReadByte = 1;
  except
    Result := False
  end;
end;

procedure TfMain.buSendFilesClick(Sender: TObject);
var
  StartTime: TDateTime;
  LoadingTime: single; // instead of real
  strLocalFolder, strDir, strFilename, strChecksum, strChecksumRemote,
  strCopiedFilesize, strSendFilesize, strCurrentFilesize, strTotalFilesize: string;
  i, intTransferredFiles, BytesRead: integer;
  intTotalFilesize, intCopiedFilesize, intCurrentFilesize, sendFileSize: int64;
  fsContainer: TFileStream;
  Buffer: array[0..BUFSIZE - 1] of byte;
  sLTemp, sLFiles: TStringList;
  boolConnectOk, boolTransferOk: boolean;
begin
  miTransferCancel.Tag := 100;
  StartTime := Now();
  sbMain.Panels[0].Text := 'get filelist...';
  fMain.Refresh;
  Screen.Cursor := crHourGlass;

  sLTemp := TStringList.Create;
  sLFiles := TStringList.Create;

  //strLocalFolder := stLocal.Path;
  intTransferredFiles := 0;
  for i := 1 to stLocal.SelectionCount do
  begin
    strLocalFolder := stLocal.Selections[i - 1].GetTextPath;
    strLocalFolder := StringReplace(strLocalFolder, '\/', '\', [rfReplaceAll]);
    strLocalFolder := StringReplace(strLocalFolder, '/', '\', [rfReplaceAll]);

    strDir := ExtractFilePath(ExcludeTrailingPathDelimiter(strLocalFolder));
    if DirectoryExists(strLocalFolder) then
      strLocalFolder := IncludeTrailingPathDelimiter(strLocalFolder);
    if DirectoryExists(strLocalFolder) then
    begin
      FindAllFiles(sLTemp, strLocalFolder);
      sLFiles.AddStrings(sLTemp);
    end
    else if FileExists(strLocalFolder) then
    begin
      sLFiles.Add(strLocalFolder);
      strLocalFolder := ExtractFileDir(strLocalFolder);
    end;
  end;

  intCopiedFilesize := 0;
  intTotalFilesize := 0;
  for i := 1 to sLFiles.Count do
    intTotalFilesize := intTotalFilesize + FileSize(sLFiles[i - 1]);

  if MessageDlg(Format('Send %d files [%s]?', [sLFiles.Count,
    FilesizeToCustomFormat(intTotalFilesize)]), mtConfirmation, [mbYes, mbNo], 0) =
    mrYes then
  begin
    try
      boolConnectOk := True;
      Socket := TInetSocket.Create(strRemoteIP, intRemotePort{, seTimeout.Value});
    except
      boolConnectOk := False;
      MessageDlg('Error connecting!', mtWarning, [mbOK], 0);
    end;

    if boolConnectOk then
    begin
      Socket.WriteByte(cmdSendFiles);
      Socket.WriteDWord(sLFiles.Count);
      Socket.WriteAnsiString(edRemoteSelectedFolder.Text);
      for i := 1 to sLFiles.Count do
      begin
        Application.ProcessMessages;
        if miTransferCancel.Tag = 100 then
        begin
          strFilename := CreateRelativePath(sLFiles[i - 1], strDir);
          try
            //boolTransferOk := SendFile(strDir, strFilename, Socket);
            //////////
            boolTransferOk := False;
            Initialize(Buffer, Length(Buffer));
            if FileExists(strDir + '\' + strFilename) then
            begin
              intCurrentFilesize := FileSize(strDir + '\' + strFilename);
              //fsContainer.Size;
              strChecksum := MD5Print(MD5File(strDir + '\' + strFilename, BUFSIZE));
              //ShowMessage(strFilename + #13 + strChecksum);

              fsContainer := TFileStream.Create(strDir + '\' + strFilename,
                fmOpenRead or fmShareDenyNone);
              try
                Socket.WriteDWord(intCurrentFilesize);
                Socket.WriteAnsiString(strChecksum);

                Socket.WriteAnsiString(strFilename);

                sendFileSize := 0;
                repeat
                  BytesRead := fsContainer.Read(Buffer, SizeOf(Buffer));
                  Socket.WriteBuffer(Buffer, BytesRead);
                  Inc(sendFileSize, BytesRead);

                  LoadingTime := DateUtils.MilliSecondsBetween(Now(), StartTime) / 1000;
                  strCopiedFilesize :=
                    FilesizeToCustomFormat(intCopiedFilesize + sendFileSize);
                  strCurrentFilesize := FilesizeToCustomFormat(intCurrentFilesize);
                  strSendFilesize := FilesizeToCustomFormat(sendFileSize);
                  strTotalFilesize := FilesizeToCustomFormat(intTotalFilesize);

                  sbMain.Panels[0].Text :=
                    Format('%d/%d files [%s/%s] sent in %s',
                    [i - 1, sLFiles.Count, strCopiedFilesize,
                    strTotalFilesize, SecondsToCustomFormat(LoadingTime)]);

                  sbMain.Panels[1].Text :=
                    Format('%s/%s', [strSendFilesize, strCurrentFilesize]);
                  sbMain.Panels[2].Text := strFilename;
                  fMain.Refresh;

                until sendFileSize >= intCurrentFilesize;

                strChecksumRemote := Socket.ReadAnsiString;
                boolTransferOk := strChecksum = strChecksumRemote;
              finally
                fsContainer.Free;
              end;
            end;

            //////////
            intCopiedFilesize := intCopiedFilesize + intCurrentFilesize;
            if boolTransferOk then
              Inc(intTransferredFiles);
          except
            MessageDlg('Error sending file "' + strDir + strFilename + '"',
              mtWarning, [mbOK], 0);
          end;
        end;
      end;
      Socket.Free;
    end;

    if miTransferCancel.Tag = 0 then
      MessageDlg('Copying files aborted!', mtInformation, [mbOK], 0);
    if intTransferredFiles <> sLFiles.Count then
      MessageDlg(Format('%d of %d files transfered successfully!',
        [intTransferredFiles, sLFiles.Count]), mtWarning, [mbOK], 0);
    miTransferCancel.Tag := 0;
    sLTemp.Free;
    sLFiles.Free;
  end;

  sbMain.Panels[0].Text := 'ready';
  sbMain.Panels[1].Text := '';
  sbMain.Panels[2].Text := 'a software created by stefan.arhip@vard.com, +40730290641';
  Screen.Cursor := crDefault;

  buRetrieveFilelistClick(Sender);
end;

procedure TfMain.buRetrieveFilelistClick(Sender: TObject);
var
  strFolder, strFileName, strFileDate, strFilter: string;
  i: integer;
  intFilesCount, intFileSize: int64;
  ConnectOk: boolean;
begin
  miTransferCancel.Tag := 100;
  sbMain.Panels[0].Text := 'connecting...';
  fMain.Refresh;
  Screen.Cursor := crHourGlass;

  try
    ConnectOk := True;
    Socket := TInetSocket.Create(strRemoteIP, intRemotePort);
    //Socket.SocketOptions:= encrypted ?;
  except
    pnDeviceOffline.Caption := 'DEVICE OFFLINE';
    pnDeviceOffline.Visible := True;
    lvRemoteFiles.Visible := False;
    ConnectOk := False;
    //ShowMessage('Unable to connect to ' + strRemoteIP);
  end;

  if ConnectOk then
  begin
    pnDeviceOffline.Visible := False;
    lvRemoteFiles.Visible := True;

    Socket.WriteByte(cmdRetrieveFilelist);
    strFolder := edRemoteSelectedFolder.Text;
    Socket.WriteAnsiString(strFolder);

    intFilesCount := Socket.ReadDWord;
    strFilter := lfRemoteFiles.Text;
    lfRemoteFiles.Text := '';
    lfRemoteFiles.FilteredListview := nil;
    lfRemoteFiles.Items.Clear;
    lvRemoteFiles.Items.BeginUpdate;
    lvRemoteFiles.Items.Clear;
    with lvRemoteFiles.Items.Add do
    begin
      Caption := '[..]';
      ImageIndex := icoUpFolder;
      SubItems.Add(''); // ext
      SubItems.Add(''); // size
      SubItems.Add(''); // date
      SubItems.Add(''); // checksum
      SubItems.Add(''); // address
    end;
    for i := 1 to intFilesCount do
    begin
      strFileName := Socket.ReadAnsiString;
      intFileSize := Socket.ReadDWord;
      strFileDate := Socket.ReadAnsiString;
      //strChecksum := Socket.ReadAnsiString;

      with lvRemoteFiles.Items.Add do
      begin
        if strFileName[Length(strFileName)] = '\' then
        begin
          ImageIndex := icoFolder;
          Caption := strFileName;
          SubItems.Add('');
          SubItems.Add('<DIR>');
        end
        else
        begin
          ImageIndex := icoFile;
          Caption := strFileName;
          SubItems.Add(ExtractFileExt(strFileName));
          SubItems.Add(FilesizeToCustomFormat(intFileSize));
        end;
        SubItems.Add(strFileDate);
        SubItems.Add(''{strChecksum});
        SubItems.Add(strFolder + strFileName);
      end;
    end;
    lvRemoteFiles.Items.EndUpdate;
    lfRemoteFiles.FilteredListview := lvRemoteDevices;
    lfRemoteFiles.Text := strFilter;
    Socket.Free;
  end;

  sbMain.Panels[0].Text := 'ready';
  sbMain.Panels[1].Text := '';
  sbMain.Panels[2].Text := 'a software created by stefan.arhip@vard.com, +40730290641';

  Screen.Cursor := crDefault;

  if cbFoldersSize.Checked then
    buRetrieveDirectorySizeClick(Sender);
  if cbFilesChecksum.Checked then
    buRetrieveFileChecksumClick(Sender);
end;

procedure TfMain.buUpdateClientClick(Sender: TObject);
const
  constFiles = 2;
var
  StartTime: TDateTime;
  LoadingTime: single;
  strDir, strFilename, strChecksum, strCheck, strCopiedFilesize,
  strCurrentFilesize, strSendFilesize, strTotalFilesize: string;
  i, intTransferredFiles: integer;
  intCurrentFilesize, intCopiedFilesize, intTotalFilesize, sendFileSize: int64;
  boolConnectOk, boolTransferOk: boolean;
  arrFiles: array [0..1] of string;
  Buffer: array[0..BUFSIZE - 1] of byte;
  BytesRead: integer;
  fsContainer: TFileStream;
begin
  strDir := IncludeTrailingPathDelimiter(ExtractFileDir(ParamStr(0)));

  arrFiles[0] := 'trex_launch.exe';
  arrFiles[1] := 'trex_client_new.exe';

  if MessageDlg('Update client?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    miTransferCancel.Tag := 100;
    StartTime := Now();
    sbMain.Panels[0].Text := 'get filelist...';
    fMain.Refresh;
    Screen.Cursor := crHourGlass;

    try
      boolConnectOk := True;
      Socket := TInetSocket.Create(strRemoteIP, intRemotePort{, seTimeout.Value});
    except
      boolConnectOk := False;
      MessageDlg('Error connecting!', mtWarning, [mbOK], 0);
    end;

    if boolConnectOk then
    begin
      Socket.WriteByte(cmdUpdate);
      Socket.WriteDWord(constFiles);
      Socket.WriteAnsiString(arrFiles[0]);

      intCopiedFilesize := 0;
      intTransferredFiles := 0;
      intTotalFilesize := 0;
      for i := Low(arrFiles) to High(arrFiles) do
        intTotalFilesize := intTotalFilesize + FileSize(strDir + '\' + arrFiles[i]);
      for i := Low(arrFiles) to High(arrFiles) do
        try
          //boolTransferOk := SendFile(strDir, arrFiles[i], Socket);
          //SendFile(const strFolder, strFilename: string; Data: TInetSocket): boolean;
          /////////

          boolTransferOk := False;
          Initialize(Buffer, Length(Buffer));
          strFilename := arrFiles[i];
          if FileExists(strDir + '\' + strFilename) then
          begin
            fsContainer := TFileStream.Create(strDir + '\' + strFilename,
              fmOpenRead or fmShareDenyNone);
            try
              intCurrentFileSize := fsContainer.Size;
              strChecksum := MD5Print(MD5File(strDir + '\' + strFilename, BUFSIZE));

              Socket.WriteDWord(intCurrentFilesize);
              Socket.WriteAnsiString(strChecksum);
              Socket.WriteAnsiString(strFilename);

              sendFileSize := 0;
              repeat
                BytesRead := fsContainer.Read(Buffer, SizeOf(Buffer));
                Socket.WriteBuffer(Buffer, BytesRead);
                Inc(sendFileSize, BytesRead);

                LoadingTime := DateUtils.MilliSecondsBetween(Now(), StartTime) / 1000;
                strCopiedFilesize :=
                  FilesizeToCustomFormat(intCopiedFilesize + sendFileSize);
                strCurrentFilesize := FilesizeToCustomFormat(intCurrentFilesize);
                strSendFilesize := FilesizeToCustomFormat(sendFileSize);
                strTotalFilesize := FilesizeToCustomFormat(intTotalFilesize);

                sbMain.Panels[0].Text :=
                  Format('%d/%d files [%s/%s] sent in %s',
                  [i + 1, constFiles, strCopiedFilesize, strTotalFilesize,
                  SecondsToCustomFormat(LoadingTime)]);

                sbMain.Panels[1].Text :=
                  Format('%s/%s', [strSendFilesize, strCurrentFilesize]);
                sbMain.Panels[2].Text := strFilename;
                fMain.Refresh;
              until sendFileSize >= intCurrentFilesize;

              strCheck := Socket.ReadAnsiString;
              boolTransferOk := strChecksum = strCheck;
            finally
              fsContainer.Free;
            end;
          end;

          /////////
          intCopiedFilesize := intCopiedFilesize + intCurrentFilesize;
          if boolTransferOk then
            Inc(intTransferredFiles);
        except
          //MessageDlg('Error sending file "' + strDir + strFilename + '"', mtWarning, [mbOK], 0);
        end;

      if intTransferredFiles <> constFiles then
        MessageDlg(Format('Error update client!'#13'%d/%d',
          [intTransferredFiles, constFiles]), mtWarning, [mbOK], 0);

      Socket.Free;

      sbMain.Panels[0].Text := 'ready';
      sbMain.Panels[1].Text := '';
      sbMain.Panels[2].Text :=
        'a software created by stefan.arhip@vard.com, +40730290641';
      Screen.Cursor := crDefault;
    end;
  end;
end;

procedure TfMain.buSelectionDeleteClick(Sender: TObject);
var
  StartTime: TDateTime;
  LoadingTime: single;
  strDir, strFilename: string;
  i, intToDeleteFiles, intDeleteCode: integer;
  sLTemp, sLFiles: TStringList;
  boolConnectOk: boolean;
begin
  miTransferCancel.Tag := 100;
  StartTime := Now();
  sbMain.Panels[0].Text := 'delete files...';
  fMain.Refresh;
  Screen.Cursor := crHourGlass;

  strDir := IncludeTrailingPathDelimiter(edRemoteSelectedFolder.Text);

  sLTemp := TStringList.Create;
  sLFiles := TStringList.Create;

  //strFolder := stLocal.Path;
  intToDeleteFiles := 0;
  for i := 1 to lvRemoteFiles.Items.Count do
    if lvRemoteFiles.Items[i - 1].Selected then
      sLFiles.Add(lvRemoteFiles.Items[i - 1].SubItems[intColumnAddress]);

  if MessageDlg(Format('Delete selected %d files and folders from remote device?',
    [sLFiles.Count]), mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    try
      boolConnectOk := True;
      Socket := TInetSocket.Create(strRemoteIP, intRemotePort{, seTimeout.Value});
    except
      boolConnectOk := False;
      MessageDlg('Error connecting!', mtWarning, [mbOK], 0);
    end;

    if boolConnectOk then
    begin
      Socket.WriteByte(cmdDeleteFiles);
      Socket.WriteDWord(sLFiles.Count);
      Socket.WriteAnsiString(strDir);
      for i := 1 to sLFiles.Count do
      begin
        Application.ProcessMessages;
        if miTransferCancel.Tag = 100 then
        begin
          strFilename := CreateRelativePath(sLFiles[i - 1], strDir);
          LoadingTime := DateUtils.MilliSecondsBetween(Now(), StartTime) / 1000;
          sbMain.Panels[0].Text :=
            Format('%d/%d filenames sent in %s',
            [i - 1, sLFiles.Count, SecondsToCustomFormat(LoadingTime)]);
          sbMain.Panels[1].Text := '';
          sbMain.Panels[2].Text := strFilename;
          fMain.Refresh;
          try
            Socket.WriteAnsiString(strFilename);
            intDeleteCode := Socket.ReadByte;
            if intDeleteCode = intOperationOk then
              Inc(intToDeleteFiles);
          except
            MessageDlg('Error deleting file "' + strDir + strFilename + '"',
              mtWarning, [mbOK], 0);
          end;
        end;
      end;
      Socket.Free;
    end;

    if miTransferCancel.Tag = 0 then
      MessageDlg('Deleting files aborted!', mtInformation, [mbOK], 0);
    //if intToDeleteFiles <> sLFiles.Count then
    //  MessageDlg(Format('%d of %d files deleted successfully!',
    //    [intToDeleteFiles, sLFiles.Count]), mtWarning, [mbOK], 0);
    miTransferCancel.Tag := 0;
    sLTemp.Free;
    sLFiles.Free;
  end;

  sbMain.Panels[0].Text := 'ready';
  sbMain.Panels[1].Text := '';
  sbMain.Panels[2].Text := 'a software created by stefan.arhip@vard.com, +40730290641';
  Screen.Cursor := crDefault;

  buRetrieveFilelistClick(Sender);
end;

procedure TfMain.buRetrieveFileChecksumClick(Sender: TObject);
var
  StartTime: TDateTime;
  LoadingTime: single;
  i, j: integer;
  boolConnectOk: boolean;
  strFilename, strChecksum: string;
  sLFiles: TStringList;
begin
  miTransferCancel.Tag := 100;
  StartTime := Now();
  sbMain.Panels[0].Text := 'get files checksum...';
  fMain.Refresh;
  Screen.Cursor := crHourGlass;

  try
    boolConnectOk := True;
    Socket := TInetSocket.Create(strRemoteIP, intRemotePort{, seTimeout.Value});
  except
    boolConnectOk := False;
    MessageDlg('Error connecting!', mtWarning, [mbOK], 0);
  end;

  sLFiles := TStringList.Create;
  for i := 1 to lvRemoteFiles.Items.Count do
    if lvRemoteFiles.Items[i - 1].Selected then
    begin
      strFilename := lvRemoteFiles.Items[i - 1].SubItems[intColumnAddress];
      if (Length(strFilename) > 0) and (strFilename[Length(strFilename)] <> '\') then
        sLFiles.Add(strFilename);
    end;

  if sLFiles.Count = 0 then
    for i := 1 to lvRemoteFiles.Items.Count do
    begin
      strFilename := lvRemoteFiles.Items[i - 1].SubItems[intColumnAddress];
      if (Length(strFilename) > 0) and (strFilename[Length(strFilename)] <> '\') then
        sLFiles.Add(strFilename);
    end;

  if boolConnectOk then
  begin
    Socket.WriteByte(cmdChecksumFiles);
    Socket.WriteDWord(sLFiles.Count);
    //Socket.WriteAnsiString(IncludeTrailingPathDelimiter(edRemoteSelectedFolder.Text));
    for i := 1 to sLFiles.Count do
    begin
      Socket.WriteAnsiString(sLFiles[i - 1]);
      strFilename := Socket.ReadAnsiString;
      strChecksum := Socket.ReadAnsiString;
      if strFilename = sLFiles[i - 1] then
      begin
        for j := 1 to lvRemoteFiles.Items.Count do
          if strFilename = lvRemoteFiles.Items[j - 1].SubItems[intColumnAddress] then
            lvRemoteFiles.Items[j - 1].SubItems[intColumnChecksum] := strChecksum;
      end;

      LoadingTime := DateUtils.MilliSecondsBetween(Now(), StartTime) / 1000;
      sbMain.Panels[0].Text :=
        Format('%d/%d files in %s', [i - 1, sLFiles.Count,
        SecondsToCustomFormat(LoadingTime)]);

      sbMain.Panels[1].Text := '';
      sbMain.Panels[2].Text := strFilename;
      fMain.Refresh;
    end;
  end;
  sLFiles.Free;

  sbMain.Panels[0].Text := 'ready';
  sbMain.Panels[1].Text := '';
  sbMain.Panels[2].Text := 'a software created by stefan.arhip@vard.com, +40730290641';
  Screen.Cursor := crDefault;
end;

procedure TfMain.buRetrieveDirectorySizeClick(Sender: TObject);
var
  StartTime: TDateTime;
  LoadingTime: single;
  i, j: integer;
  intFileSize: int64;
  boolConnectOk: boolean;
  strDirectory: string;
  sLDirectories: TStringList;
begin
  miTransferCancel.Tag := 100;
  StartTime := Now();
  sbMain.Panels[0].Text := 'get directories size...';
  fMain.Refresh;
  Screen.Cursor := crHourGlass;

  try
    boolConnectOk := True;
    Socket := TInetSocket.Create(strRemoteIP, intRemotePort{, seTimeout.Value});
  except
    boolConnectOk := False;
    MessageDlg('Error connecting!', mtWarning, [mbOK], 0);
  end;

  sLDirectories := TStringList.Create;
  for i := 1 to lvRemoteFiles.Items.Count do
    if lvRemoteFiles.Items[i - 1].Selected then
    begin
      strDirectory := lvRemoteFiles.Items[i - 1].SubItems[intColumnAddress];
      if (Length(strDirectory) > 0) and (strDirectory[Length(strDirectory)] = '\') then
        sLDirectories.Add(strDirectory);
    end;

  if sLDirectories.Count = 0 then
    for i := 1 to lvRemoteFiles.Items.Count do
    begin
      strDirectory := lvRemoteFiles.Items[i - 1].SubItems[intColumnAddress];
      if (Length(strDirectory) > 0) and (strDirectory[Length(strDirectory)] = '\') then
        sLDirectories.Add(strDirectory);
    end;

  if boolConnectOk then
  begin
    Socket.WriteByte(cmdSizeDirectory);
    Socket.WriteDWord(sLDirectories.Count);
    //Socket.WriteAnsiString(IncludeTrailingPathDelimiter(edRemoteSelectedFolder.Text));
    for i := 1 to sLDirectories.Count do
    begin
      Socket.WriteAnsiString(sLDirectories[i - 1]);
      strDirectory := Socket.ReadAnsiString;
      intFileSize := Socket.ReadDWord;
      if strDirectory = sLDirectories[i - 1] then
      begin
        for j := 1 to lvRemoteFiles.Items.Count do
          if strDirectory = lvRemoteFiles.Items[j - 1].SubItems[intColumnAddress] then
            lvRemoteFiles.Items[j - 1].SubItems[intColumnSize] :=
              FilesizeToCustomFormat(intFileSize);
      end;

      LoadingTime := DateUtils.MilliSecondsBetween(Now(), StartTime) / 1000;
      sbMain.Panels[0].Text :=
        Format('%d/%d folders in %s', [i - 1, sLDirectories.Count,
        SecondsToCustomFormat(LoadingTime)]);

      sbMain.Panels[1].Text := '';
      sbMain.Panels[2].Text := strDirectory;
      fMain.Refresh;
    end;
  end;
  sLDirectories.Free;

  sbMain.Panels[0].Text := 'ready';
  sbMain.Panels[1].Text := '';
  sbMain.Panels[2].Text := 'a software created by stefan.arhip@vard.com, +40730290641';
  Screen.Cursor := crDefault;
end;

procedure TfMain.cbRootEditingDone(Sender: TObject);
begin
  if DirectoryExists(cbRoot.Text) then
    stLocal.Root := cbRoot.Text;
end;

procedure TfMain.FormActivate(Sender: TObject);
var
  i: integer;
begin
  //  tabDeviceList.TAb;
  //tabDeviceList.GetImageIndex(0) := 14;

  lvRemoteDevices.Items.Clear;
  tabDeviceList.Tabs.Clear;
  if (lbRemoteName.Items.Count = lbRemoteIP.Items.Count) and
    (lbRemoteName.Items.Count = lbRemotePort.Items.Count) then
  begin
    for i := 1 to lbRemoteName.Items.Count do
      with lvRemoteDevices.Items.Add do
      begin
        ImageIndex := icoComputer;
        Caption := lbRemoteName.Items[i - 1];
        SubItems.Add(lbRemoteIP.Items[i - 1]);
        SubItems.Add(lbRemotePort.Items[i - 1]);
      end;
    tabDeviceList.Tabs.AddStrings(lbRemoteName.Items);
    if tabDeviceList.Tag > -1 then
      tabDeviceList.TabIndex := tabDeviceList.Tag
    else
      tabDeviceList.TabIndex := 1;
    tabDeviceListChange(Sender);
  end;
end;

procedure TfMain.FormCreate(Sender: TObject);
var
  FileDate: integer;
begin
  laUsername.Caption := 'User: ' + GetUserFromWindows;
  FileDate := FileAge(Application.ExeName);
  if FileDate > -1 then
    laVersion.Caption := 'Version: ' + FormatDateTime('yyyymmdd-hhnn',
      FileDateToDateTime(FileDate));

  laLazarus.Caption := 'Lazarus: ' + lcl_version;
  laFPC.Caption := 'FPC: ' + {$I %FPCVersion%};
  laTarget.Caption := 'Target: ' + {$I %FPCTarget%};

  stLocal.Root := ExtractFileDir(ParamStr(0));
  if cbRoot.ItemIndex > -1 then
    if DirectoryExists(cbRoot.Items[cbRoot.ItemIndex]) then
      stLocal.Root := cbRoot.Items[cbRoot.ItemIndex];
  //tabDeviceList.TabIndex := 1;
end;

procedure TfMain.hcRemoteEditSectionClick(HeaderControl: TCustomHeaderControl;
  Section: THeaderSection);
var
  intDeviceIndex: integer;
begin
  intDeviceIndex := lvRemoteDevices.ItemIndex;

  case Section.ImageIndex of
    icoAdd:
    begin
      fDevice.leName.Text := '';
      fDevice.leIP.Text := '';
      fDevice.sePort.Value := 1212;
      if fDevice.ShowModal = mrOk then
      begin
        lbRemoteName.Items.Add(fDevice.leName.Text);
        lbRemoteIP.Items.Add(fDevice.leIP.Text);
        lbRemotePort.Items.Add(IntToStr(fDevice.sePort.Value));
        with lvRemoteDevices.Items.Add do
        begin
          Caption := fDevice.leName.Text;
          SubItems.Add(fDevice.leIP.Text);
          SubItems.Add(IntToStr(fDevice.sePort.Value));
        end;
        tabDeviceList.Tabs.Add(fDevice.leName.Text);
      end;
    end;
    icoEdit:
      if intDeviceIndex > -1 then
      begin
        fDevice.leName.Text := lbRemoteName.Items[intDeviceIndex];
        fDevice.leIP.Text := lbRemoteIP.Items[intDeviceIndex];
        fDevice.sePort.Value := StrToInt(lbRemotePort.Items[intDeviceIndex]);
        if fDevice.ShowModal = mrOk then
        begin
          lbRemoteName.Items[intDeviceIndex] := fDevice.leName.Text;
          lbRemoteIP.Items[intDeviceIndex] := fDevice.leIP.Text;
          lbRemotePort.Items[intDeviceIndex] := IntToStr(fDevice.sePort.Value);

          lvRemoteDevices.Items[intDeviceIndex].Caption := fDevice.leName.Text;
          lvRemoteDevices.Items[intDeviceIndex].SubItems[0] := fDevice.leIP.Text;
          lvRemoteDevices.Items[intDeviceIndex].SubItems[1] :=
            IntToStr(fDevice.sePort.Value);
          tabDeviceList.Tabs[intDeviceIndex] := fDevice.leName.Text;
        end;
      end;
    icoDelete:
      if intDeviceIndex > -1 then
        if MessageDlg('Delete selected remote device?', mtConfirmation,
          [mbYes, mbNo], 0) = mrYes then
        begin
          lbRemoteName.Items.Delete(intDeviceIndex);
          lbRemoteIP.Items.Delete(intDeviceIndex);
          lbRemotePort.Items.Delete(intDeviceIndex);
          lvRemoteDevices.Items.Delete(intDeviceIndex);
          tabDeviceList.Tabs.Delete(intDeviceIndex);
        end;
  end;

end;

procedure TfMain.lvRemoteFilesDblClick(Sender: TObject);
var
  intIndex: integer;
  strFolder, strSelected: string;
begin
  intIndex := lvRemoteFiles.ItemIndex;
  if intIndex > -1 then
  begin
    strFolder := edRemoteSelectedFolder.Text;
    strSelected := lvRemoteFiles.Items[intIndex].Caption;
    if strSelected = '[..]' then
      strFolder := ExtractFileDir(ExcludeTrailingPathDelimiter(strFolder))
    else if strSelected[Length(strSelected)] = '\' then
      strFolder := IncludeTrailingPathDelimiter(strFolder) + strSelected;
    edRemoteSelectedFolder.Text := IncludeTrailingPathDelimiter(strFolder);
    buRetrieveFilelistClick(Sender);
  end;
end;

procedure TfMain.lvRemoteFilesSelectItem(Sender: TObject; Item: TListItem;
  Selected: Boolean);
var
  i, intItemsSelected: integer;
begin
  intItemsSelected := 0;
  for i := 1 to lvRemoteFiles.Items.Count do
    if lvRemoteFiles.Items[i - 1].Selected then
      Inc(intItemsSelected);
  //miFolderCreate.Enabled := intItemsSelected = 1;
  buItemRename.Enabled := intItemsSelected = 1;
  buSelectionDelete.Enabled := intItemsSelected > 0;
end;

procedure TfMain.miFolderCreateClick(Sender: TObject);
var
  strDir, strFolder: string;
  //intCreateDirectory: byte;
  ConnectOk: boolean;
begin
  strFolder := 'New folder';
  if InputQuery('New folder', 'Type name of new folder', False, strFolder) then
  begin
    try
      ConnectOk := True;
      Socket := TInetSocket.Create(strRemoteIP, intRemotePort);
    except
      pnDeviceOffline.Caption := 'DEVICE OFFLINE';
      pnDeviceOffline.Visible := True;
      lvRemoteFiles.Visible := False;
      ConnectOk := False;
      ShowMessage('Unable to connect to ' + strRemoteIP);
    end;

    if ConnectOk then
    begin
      Socket.WriteByte(cmdCreateDirectory);
      strDir := IncludeTrailingPathDelimiter(edRemoteSelectedFolder.Text);
      Socket.WriteAnsiString(strDir + strFolder);
      //intCreateDirectory := Socket.ReadDWord;
      // MessageDlg('Error on creating folder!', mtWarning, [mbOk],0);
      Socket.Free;
      buRetrieveFilelistClick(Sender);
    end;
  end;
end;

procedure TfMain.miItemRenameClick(Sender: TObject);
var
  strDir, strFolderOld, strFolderNew: string;
  //intRenameDirectory: byte;
  ConnectOk: boolean;
begin
  if lvRemoteFiles.ItemIndex >= 0 then
  begin
    strFolderOld := lvRemoteFiles.Items[lvRemoteFiles.ItemIndex].SubItems
      [intColumnAddress];
    strFolderNew := ExtractFileName(ExcludeTrailingPathDelimiter(strFolderOld));
    if InputQuery('Rename folder', 'Type new name for selected folder',
      False, strFolderNew) and
      (CompareText(strFolderNew, ExtractFileDir(strFolderOld)) <> 0) then
    begin
      try
        ConnectOk := True;
        Socket := TInetSocket.Create(strRemoteIP, intRemotePort);
      except
        pnDeviceOffline.Caption := 'DEVICE OFFLINE';
        pnDeviceOffline.Visible := True;
        lvRemoteFiles.Visible := False;
        ConnectOk := False;
        ShowMessage('Unable to connect to ' + strRemoteIP);
      end;

      if ConnectOk then
      begin
        Socket.WriteByte(cmdRenameDirectory);
        strDir := IncludeTrailingPathDelimiter(edRemoteSelectedFolder.Text);
        Socket.WriteAnsiString(strFolderOld);
        Socket.WriteAnsiString(strDir + strFolderNew);
        //intRenameDirectory := Socket.ReadDWord;
        //MessageDlg('Error on renaming folder!', mtWarning, [mbOk],0);
        Socket.Free;
        buRetrieveFilelistClick(Sender);
      end;
    end;
  end;
end;

procedure TfMain.miListSelectAllClick(Sender: TObject);
var
  i: integer;
begin
  for i := 1 to lvRemoteFiles.Items.Count do
    lvRemoteFiles.Items[i - 1].Selected := True;
end;

procedure TfMain.miLocaListCopyFilenameClick(Sender: TObject);
var
  i: integer;
  sL: TStringList;
  strLocalFolder: string;
begin
  sL := TStringList.Create;
  for i := 1 to stLocal.Items.Count do
    if stLocal.Selections[i - 1].GetTextPath <> '' then
    begin
      strLocalFolder := stLocal.Selections[i - 1].GetTextPath;
      strLocalFolder := StringReplace(strLocalFolder, '\/', '\', [rfReplaceAll]);
      strLocalFolder := StringReplace(strLocalFolder, '/', '\', [rfReplaceAll]);
      sL.Add(strLocalFolder);
    end;
  Clipboard.AsText := sL.Text;
  sL.Free;
end;

procedure TfMain.miLocalListOpenClick(Sender: TObject);
var
  strLocalFolder: string;
  i: integer;
begin
  for i := 1 to stLocal.Items.Count do
    if stLocal.Selections[i - 1].GetTextPath <> '' then
    begin
      strLocalFolder := stLocal.Selections[i - 1].GetTextPath;
      strLocalFolder := StringReplace(strLocalFolder, '\/', '\', [rfReplaceAll]);
      strLocalFolder := StringReplace(strLocalFolder, '/', '\', [rfReplaceAll]);

      //strDir := ExtractFilePath(ExcludeTrailingPathDelimiter(strLocalFolder));
      ShowMessage(strLocalFolder);
      ShellExecute(fMain.Handle, PChar('open'), PChar(strLocalFolder),
        PChar(''), PChar(''), 1);
    end;
end;

procedure TfMain.miLocalListRefreshClick(Sender: TObject);
var
  strRoot: string;
begin
  strRoot := stLocal.Root;
  stLocal.Root := '';
  stLocal.Root := strRoot;
end;

procedure TfMain.miTransferCancelClick(Sender: TObject);
begin
  miTransferCancel.Tag := 0;
end;

procedure TfMain.pcMainChange(Sender: TObject);
begin
  if pcMain.TabIndex = tabAboutIndex then
  begin
    AnimationIndex := ilAnimation.Count - 1;
    Timer1Timer(Sender);
    Timer1.Interval := 100; // pause at begining?
    Timer1.Enabled := True;
  end
  else
    Timer1.Enabled := False;
end;

procedure TfMain.pmLocalPopup(Sender: TObject);
begin
  miLocalSendSelected.Enabled := stLocal.SelectionCount > 0;
end;

procedure TfMain.pmRemoteFilesPopup(Sender: TObject);
var
  i, intItemsSelected: integer;
begin
  intItemsSelected := 0;
  for i := 1 to lvRemoteFiles.Items.Count do
    if lvRemoteFiles.Items[i - 1].Selected then
      Inc(intItemsSelected);
  //miFolderCreate.Enabled := intItemsSelected = 1;
  miItemRename.Enabled := intItemsSelected = 1;
  miSelectionDelete.Enabled := intItemsSelected > 0;
end;

procedure TfMain.tabDeviceListChange(Sender: TObject);
var
  strFolder: string;
  ConnectOk: boolean;
begin
  if tabDeviceList.TabIndex = -1 then exit;

  tabDeviceList.Tag := tabDeviceList.TabIndex;

  miTransferCancel.Tag := 100;
  sbMain.Panels[0].Text := 'connecting...';

  pnDeviceOffline.Caption := 'CONNECTING...';
  pnDeviceOffline.Visible := True;
  lvRemoteFiles.Visible := False;

  fMain.Refresh;
  Screen.Cursor := crHourGlass;

  strRemoteName := lbRemoteName.Items[tabDeviceList.TabIndex];
  strRemoteIP := lbRemoteIP.Items[tabDeviceList.TabIndex];
  intRemotePort := StrToInt(lbRemotePort.Items[tabDeviceList.TabIndex]);

  hcRemote.Sections[0].Text := 'Name: ' + strRemoteName;
  hcRemote.Sections[1].Text := 'IP: ' + strRemoteIP;
  hcRemote.Sections[2].Text := 'Port: ' + IntToStr(intRemotePort);

  try
    ConnectOk := True;
    Socket := TInetSocket.Create(strRemoteIP, intRemotePort);
  except
    pnDeviceOffline.Caption := 'DEVICE OFFLINE';
    pnDeviceOffline.Visible := True;
    lvRemoteFiles.Visible := False;
    ConnectOk := False;
    //ShowMessage('Unable to connect to ' + strRemoteIP);
  end;

  if ConnectOk then
  begin
    Socket.WriteByte(cmdRetrieveDirectory);
    strFolder := Socket.ReadAnsiString;
    Socket.Free;
    pnDeviceOffline.Visible := False;
    lvRemoteFiles.Visible := True;

    edRemoteSelectedFolder.Text := strFolder;
    buRetrieveFilelistClick(Sender);
  end;

  sbMain.Panels[0].Text := 'ready';
  sbMain.Panels[1].Text := '';
  sbMain.Panels[2].Text := 'a software created by stefan.arhip@vard.com, +40730290641';
  Screen.Cursor := crDefault;
end;

procedure TfMain.tabDeviceListGetImageIndex(Sender: TObject;
  TabIndex: integer; var ImageIndex: integer);
begin
  case TabIndex of
    0:
      ImageIndex := 0;
    1:
      ImageIndex := 1;
    else
      ImageIndex := 2;
  end;
end;

procedure TfMain.Timer1Timer(Sender: TObject);
var
  bmp: Graphics.TBitmap;
begin
  bmp := Graphics.TBitmap.Create;
  try
    bmp.Canvas.Rectangle(0, 0, 16, 16);
    ilAnimation.GetBitmap(AnimationIndex, bmp);

    //Application.Icon.Assign(bmp);

    Image1.Picture.Assign(bmp);

    Inc(AnimationIndex);
    if AnimationIndex >= ilAnimation.Count then
    begin
      AnimationIndex := 0;
      Timer1.Interval := 100;  // pause if needed
    end
    else
      Timer1.Interval := 100;

  finally
    bmp.Free;
  end;
end;

end.
