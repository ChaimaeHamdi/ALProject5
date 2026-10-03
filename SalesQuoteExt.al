tableextension 50100 ItemAutoCreatedExt extends Item
{
    fields
    {
        field(50100; "Auto Created"; Boolean)
        {
            Caption = 'Article auto. Créer';
            DataClassification = CustomerContent;
        }
    }
}


tableextension 50101 SalesSetupCatalogExt extends "Sales & Receivables Setup"
{
    fields
    {
        field(50100; "Default Catalog Item Template"; Code[20])
        {
            Caption = 'Modèle article créé depuis catalogue';
            DataClassification = CustomerContent;
            TableRelation = "Item Templ.".Code;
        }

        field(50101; "Default Catalog Vendor No."; Code[20])
        {
            Caption = 'Fournisseur catalogue par défaut';
            DataClassification = CustomerContent;
            TableRelation = Vendor."No.";
        }
    }
}


tableextension 50102 SalesLineCatalogItemExt extends "Sales Line"
{
    fields
    {
        field(50100; "Catalog Item Entry No."; Code[20])
        {
            Caption = 'Code article catalogue';
            DataClassification = CustomerContent;
            TableRelation = "Nonstock Item"."Entry No.";
        }
    }
}


pageextension 50100 "Sales Quotes Ext" extends "Sales Quotes"
{
    actions
    {
        addlast(Action1102601026)
        {
            action(ImporterDevis)
            {
                Caption = 'Importer devis';
                ApplicationArea = All;
                Image = Import;

                trigger OnAction()
                var
                    FileName: Text;
                    InStream: InStream;
                    ExcelImport: Codeunit "Excel Import Management";
                begin
                    if UploadIntoStream(
                        'Sélectionner le fichier Excel',
                        '',
                        'Fichiers Excel (*.xlsx)|*.xlsx',
                        FileName,
                        InStream)
                    then
                        ExcelImport.ImportExcel(
                            InStream,
                            Rec);
                end;
            }

            action(TelechargerModeleDevis)
            {
                Caption = 'Télécharger modèle Excel';
                ApplicationArea = All;
                Image = Export;

                trigger OnAction()
                var
                    ExcelImport: Codeunit "Excel Import Management";
                begin
                    ExcelImport.DownloadTemplate();
                end;
            }
        }
    }
}


pageextension 50101 "Sales Quote Card Import Ext" extends "Sales Quote"
{
    actions
    {
        modify(MakeOrder)
        {
            Visible = false;
        }

        addafter("Archive Document_Promoted")
        {
            actionref(
                ImporterDevis_Promoted;
            ImporterDevisDepuisCarte)
            {
            }

            actionref(
                CreerCommandeCatalogue_Promoted;
            CreerCommandeCatalogue)
            {
            }
        }

        addafter(CopyDocument)
        {
            action(ImporterDevisDepuisCarte)
            {
                Caption = 'Importer devis';
                ApplicationArea = All;
                Image = Import;

                trigger OnAction()
                var
                    FileName: Text;
                    InStream: InStream;
                    ExcelImport: Codeunit "Excel Import Management";
                begin
                    if UploadIntoStream(
                        'Sélectionner le fichier Excel',
                        '',
                        'Fichiers Excel (*.xlsx)|*.xlsx',
                        FileName,
                        InStream)
                    then
                        ExcelImport.ImportExcel(
                            InStream,
                            Rec);
                end;
            }
        }

        addafter(ImporterDevisDepuisCarte)
        {
            action(TelechargerModeleDevisDepuisCarte)
            {
                Caption = 'Télécharger modèle Excel';
                ApplicationArea = All;
                Image = Export;

                trigger OnAction()
                var
                    ExcelImport: Codeunit "Excel Import Management";
                begin
                    ExcelImport.DownloadTemplate();
                end;
            }
        }

        addafter(MakeOrder)
        {
            action(CreerCommandeCatalogue)
            {
                Caption = 'Créer commande';
                ApplicationArea = All;
                Image = MakeOrder;

                trigger OnAction()
                var
                    QuoteCatalogMgt: Codeunit "Sales Quote Catalog Mgt.";
                begin
                    QuoteCatalogMgt.ConvertQuoteToOrder(
                        Rec);
                end;
            }
        }
    }
}


pageextension 50102 "Item Card Auto Created Ext" extends "Item Card"
{
    layout
    {
        addlast(Content)
        {
            field("Auto Created"; Rec."Auto Created")
            {
                ApplicationArea = All;
                ToolTip =
                    'Indique que cet article a été créé automatiquement depuis un article de catalogue.';
            }
        }
    }
}


pageextension 50103 "Sales Setup Catalog Ext" extends "Sales & Receivables Setup"
{
    layout
    {
        addlast(General)
        {
            field(
                "Default Catalog Item Template";
            Rec."Default Catalog Item Template")
            {
                ApplicationArea = All;
                ToolTip =
                    'Spécifie le modèle utilisé pour créer automatiquement un article depuis un article de catalogue.';
            }
        }
    }
}


// IMPORTANT : NE PAS CREER DE NOUVEAU BOUTON VALIDER
pageextension 50104 "Sales Order Validate Ext" extends "Sales Order"
{
}


pageextension 50105 "Sales Quote Lines Catalog Ext" extends "Sales Quote Subform"
{
    layout
    {
        addafter("No.")
        {
            field(
                "Catalog Item Entry No.";
            Rec."Catalog Item Entry No.")
            {
                ApplicationArea = All;
                Editable = false;
                ToolTip =
                    'Spécifie le code de l''article catalogue importé depuis le devis client.';
            }
        }
    }
}


pageextension 50106 "Sales Order Lines Catalog Ext" extends "Sales Order Subform"
{
    layout
    {
        addafter("No.")
        {
            field(
                "Catalog Item Entry No.";
            Rec."Catalog Item Entry No.")
            {
                ApplicationArea = All;
                Editable = false;
                ToolTip =
                    'Spécifie le code de l''article catalogue avant sa conversion en article réel.';
            }
        }
    }
}