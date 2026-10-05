table 50100 Department
{
    Caption = 'Department';

    fields
    {
        field(1; ID; Code[20])
        {
            Caption = 'ID';
        }

        field(2; Description; Text[100])
        {
            Caption = 'Description';
        }

        field(3; Status; Enum "Department Status")
        {
            Caption = 'Statut';
        }
    }

    keys
    {
        key(PK; ID)
        {
            Clustered = true;
        }
    }
}