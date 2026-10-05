page 50101 "Department List"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = Department;
    Caption = 'Departments';

    layout
    {
        area(content)
        {
            repeater(General)
            {
                field(ID; Rec.ID)
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
            }
        }
    }
}