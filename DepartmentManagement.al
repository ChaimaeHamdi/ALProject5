enum 50107 "Department Status"
{
    Extensible = true;

    value(0; Open)
    {
        Caption = 'Ouvert';
    }

    value(1; Closed)
    {
        Caption = 'Clôturé';
    }
}

table 50108 Department
{
    Caption = 'Département';
    DataClassification = CustomerContent;
    LookupPageId = "Department List";
    DrillDownPageId = "Department List";

    fields
    {
        field(1; Code; Code[20])
        {
            Caption = 'Code';
            NotBlank = true;
        }

        field(2; Description; Text[100])
        {
            Caption = 'Description';
        }

        field(3; Status; Enum "Department Status")
        {
            Caption = 'Statut';
        }

        field(4; "Employee Count"; Integer)
        {
            Caption = 'Nombre de salariés';
            FieldClass = FlowField;
            CalcFormula = count(Employee where("Department Code" = field(Code)));
            Editable = false;
        }
    }

    keys
    {
        key(PK; Code)
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; Code, Description)
        {
        }
    }

    trigger OnModify()
    var
        Employee: Record Employee;
    begin
        Employee.SetRange("Department Code", Code);
        if Employee.FindSet() then
            if not Confirm('Le département est associé à des salariés. Voulez-vous le modifier ?') then
                Error('Modification du département annulée.');
    end;

    trigger OnDelete()
    var
        Employee: Record Employee;
    begin
        if Status = Status::Open then
            Error('Impossible de supprimer un département dont le statut est Ouvert.');

        Employee.SetRange("Department Code", Code);
        if Employee.FindSet() then
            Error('Impossible de supprimer un département qui a déjà des salariés.');
    end;
}

tableextension 50109 EmployeeDepartmentExt extends Employee
{
    fields
    {
        field(50100; "Department Code"; Code[20])
        {
            Caption = 'Code Département';
            TableRelation = Department.Code;
            DataClassification = CustomerContent;

            trigger OnValidate()
            var
                DepartmentRec: Record Department;
            begin
                if "Department Code" = '' then begin
                    "Department Description" := '';
                    exit;
                end;

                if DepartmentRec.Get("Department Code") then
                    "Department Description" := DepartmentRec.Description
                else
                    "Department Description" := '';
            end;
        }

        field(50101; "Department Description"; Text[100])
        {
            Caption = 'Description département';
            Editable = false;
            DataClassification = CustomerContent;
        }
    }
}

page 50110 "Department List"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = Department;
    Caption = 'Liste des départements';
    Editable = true;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field(Code; Rec.Code)
                {
                    ApplicationArea = All;
                }

                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                }

                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    StyleExpr = StatusStyle;
                }

                field("Employee Count"; Rec."Employee Count")
                {
                    ApplicationArea = All;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ShowEmployees)
            {
                Caption = 'Salariés';
                ApplicationArea = All;
                Image = CustomerList;

                trigger OnAction()
                var
                    DepartmentEmployees: Page "Department Employee List";
                begin
                    DepartmentEmployees.SetDepartmentCode(Rec.Code);
                    DepartmentEmployees.Run();
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        if Rec.Status = Rec.Status::Open then
            StatusStyle := 'Favorable'
        else
            StatusStyle := 'Unfavorable';
    end;

    var
        StatusStyle: Text;
}

page 50111 "Department Card"
{
    PageType = Card;
    ApplicationArea = All;
    SourceTable = Department;
    Caption = 'Fiche département';

    layout
    {
        area(Content)
        {
            group(General)
            {
                field(Code; Rec.Code)
                {
                    ApplicationArea = All;
                }

                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                }

                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                }

                field("Employee Count"; Rec."Employee Count")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
            }

            part(EmployeeSubform; "Employee Subform")
            {
                Caption = 'Salariés';
                SubPageLink = "Department Code" = FIELD(Code);
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(Employees)
            {
                Caption = 'Salariés';
                ApplicationArea = All;
                Image = CustomerList;

                trigger OnAction()
                var
                    DepartmentEmployees: Page "Department Employee List";
                begin
                    DepartmentEmployees.SetDepartmentCode(Rec.Code);
                    DepartmentEmployees.Run();
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        if Rec."Employee Count" > 5 then
            Message('Vous avez dépassé les 5 salariés pour ce département');
    end;
}

page 50112 "Employee Subform"
{
    PageType = ListPart;
    ApplicationArea = All;
    SourceTable = Employee;
    Caption = 'Salariés';

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("No."; Rec."No.")
                {
                    ApplicationArea = All;
                }

                field("First Name"; Rec."First Name")
                {
                    ApplicationArea = All;
                }

                field("Last Name"; Rec."Last Name")
                {
                    ApplicationArea = All;
                }

                field("Department Code"; Rec."Department Code")
                {
                    ApplicationArea = All;
                }

                field("Department Description"; Rec."Department Description")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
            }
        }
    }
}

page 50113 "Department Employee List"
{
    PageType = List;
    ApplicationArea = All;
    SourceTable = Employee;
    Caption = 'Salariés du département';
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("No."; Rec."No.")
                {
                    ApplicationArea = All;
                }

                field("First Name"; Rec."First Name")
                {
                    ApplicationArea = All;
                }

                field("Last Name"; Rec."Last Name")
                {
                    ApplicationArea = All;
                }

                field("Department Code"; Rec."Department Code")
                {
                    ApplicationArea = All;
                }

                field("Department Description"; Rec."Department Description")
                {
                    ApplicationArea = All;
                }
            }
        }
    }

    procedure SetDepartmentCode(NewDepartmentCode: Code[20])
    begin
        DepartmentCodeFilter := NewDepartmentCode;
        if DepartmentCodeFilter <> '' then
            Rec.SetRange("Department Code", DepartmentCodeFilter);
    end;

    trigger OnOpenPage()
    begin
        if DepartmentCodeFilter <> '' then
            Rec.SetRange("Department Code", DepartmentCodeFilter);
    end;

    var
        DepartmentCodeFilter: Code[20];
}

page 50114 "Employee Worksheet"
{
    PageType = Worksheet;
    ApplicationArea = All;
    SourceTable = Employee;
    Caption = 'Feuille de travail des employés';
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("No."; Rec."No.")
                {
                    ApplicationArea = All;
                }

                field("First Name"; Rec."First Name")
                {
                    ApplicationArea = All;
                }

                field("Last Name"; Rec."Last Name")
                {
                    ApplicationArea = All;
                }

                field("Department Code"; Rec."Department Code")
                {
                    ApplicationArea = All;
                }

                field("Department Description"; Rec."Department Description")
                {
                    ApplicationArea = All;
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        ApplyFilters();
    end;

    procedure SetDepartmentFilter(NewDepartmentCode: Code[20])
    begin
        Department := NewDepartmentCode;
        ApplyFilters();
    end;

    procedure SetStatusFilter(NewStatus: Enum "Department Status")
    begin
        Status := NewStatus;
        ApplyFilters();
    end;

    local procedure ApplyFilters()
    var
        DepartmentRec: Record Department;
        DepartmentCodes: Text;
    begin
        Rec.Reset();
        Rec.SetRange("Department Code");

        if Department <> '' then
            Rec.SetRange("Department Code", Department);

        if (Status = Status::Open) or (Status = Status::Closed) then begin
            DepartmentRec.SetRange(Status, Status);
            if DepartmentRec.FindSet() then begin
                repeat
                    if DepartmentCodes = '' then
                        DepartmentCodes := DepartmentRec.Code
                    else
                        DepartmentCodes := StrSubstNo('%1|%2', DepartmentCodes, DepartmentRec.Code);
                until DepartmentRec.Next() = 0;
            end;

            if DepartmentCodes <> '' then
                Rec.SetFilter("Department Code", DepartmentCodes);
        end;
    end;

    var
        Department: Code[20];
        Status: Enum "Department Status";
}

pageextension 50115 "Employee List Department Ext" extends "Employee List"
{
    layout
    {
        modify("First Name")
        {
            Visible = false;
        }

        modify("Job Title")
        {
            Visible = false;
        }

        addlast(Content)
        {
            field("Department Description"; Rec."Department Description")
            {
                ApplicationArea = All;
                Editable = false;
            }
        }
    }
}

pageextension 50116 "Employee Card Department Ext" extends "Employee Card"
{
    layout
    {
        modify("First Name")
        {
            Visible = false;
        }

        modify("Last Name")
        {
            Visible = false;
        }

        addlast(Content)
        {
            field("Department Description"; Rec."Department Description")
            {
                ApplicationArea = All;
                Editable = false;
            }
        }
    }
}
