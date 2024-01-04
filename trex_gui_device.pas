unit trex_gui_device;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ButtonPanel, ExtCtrls,
  StdCtrls, Spin;

type

  { TfDevice }

  TfDevice = class(TForm)
    buPanel: TButtonPanel;
    Label1: TLabel;
    leName: TLabeledEdit;
    leIP: TLabeledEdit;
    sePort: TSpinEdit;
    procedure leNameChange(Sender: TObject);
  private

  public
  end;

var
  fDevice: TfDevice;

implementation

{$R *.lfm}

{ TfDevice }

procedure StringSplit(Delimiter: char; Str: string; ListOfStrings: TStrings);
begin
  ListOfStrings.Clear;
  ListOfStrings.Delimiter := Delimiter;
  ListOfStrings.StrictDelimiter := True;
  ListOfStrings.DelimitedText := Str;
end;

function TryStrToIntCustom(s: string; DefaultIfError: integer): integer;
begin
  if not TryStrToInt(s, Result) then
    Result := DefaultIfError;
end;

function IsCorrectIP(Ip: string): boolean;
var
  sLSplit: TStringList;
  str: string;
begin
  sLSplit := TStringList.Create;
  StringSplit('.', Ip, sLSplit);
  Result := sLSplit.Count = 4;
  if Result then
    for str in sLSplit do
      if not TryStrToIntCustom(str, -1) in [0..255] then
        Result := False;
  sLSplit.Free;
end;

procedure TfDevice.leNameChange(Sender: TObject);
begin
  buPanel.OKButton.Enabled := (Length(leName.Text) >= 3) and
    (IsCorrectIP(leIP.Text)) and (sePort.Value > 0);
end;

end.
