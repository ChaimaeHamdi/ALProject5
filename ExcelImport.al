codeunit 50100 "Excel Import Management"
{
    procedure ImportExcel(InStream: InStream; SalesHeader: Record "Sales Header")
    var
        TempExcelBuffer: Record "Excel Buffer" temporary;
        SalesLine: Record "Sales Line";
        Item: Record Item;
        NonstockItem: Record "Nonstock Item";
        SheetName: Text[250];
        CodeArticle: Code[20];
        Quantite: Decimal;
        PrixUnitaire: Decimal;
        RowNo: Integer;
        MaxRowNo: Integer;
    begin
        SalesHeader.TestField(
            "Document Type",
            SalesHeader."Document Type"::Quote);

        SalesHeader.TestField(
            Status,
            SalesHeader.Status::Open);

        SheetName := TempExcelBuffer.SelectSheetsNameStream(InStream);
        if SheetName = '' then
            Error('Le classeur Excel ne contient aucune feuille.');

        TempExcelBuffer.OpenBookStream(InStream, SheetName);
        TempExcelBuffer.ReadSheet();
        TempExcelBuffer.CloseBook();
        if not TempExcelBuffer.FindLast() then
            Error('Le fichier Excel est vide.');

        MaxRowNo := TempExcelBuffer."Row No.";
        RowNo := 2;
        while RowNo <= MaxRowNo do begin

            CodeArticle := GetCellValue(
                TempExcelBuffer,
                RowNo,
                1);

            Quantite := GetDecimalValue(
                TempExcelBuffer,
                RowNo,
                2);

            PrixUnitaire := GetDecimalValue(
                TempExcelBuffer,
                RowNo,
                3);
            if CodeArticle <> '' then begin

                // =====================================================
                // CAS 1 : L'article existe déjà
                // =====================================================

                if Item.Get(CodeArticle) then begin

                    SalesLine.Reset();

                    SalesLine.SetRange(
                        "Document Type",
                        SalesHeader."Document Type");

                    SalesLine.SetRange(
                        "Document No.",
                        SalesHeader."No.");

                    SalesLine.SetRange(
                        "No.",
                        CodeArticle);

                    SalesLine.SetRange(
                        "Catalog Item Entry No.",
                        '');
                    if SalesLine.FindFirst() then begin

                        SalesLine.Validate(
                            Quantity,
                            Quantite);

                        SalesLine.Validate(
                            "Unit Price",
                            PrixUnitaire);

                        SalesLine.Modify(true);
                    end else begin

                        SalesLine.Init();

                        SalesLine."Document Type" :=
                            SalesHeader."Document Type";

                        SalesLine."Document No." :=
                            SalesHeader."No.";

                        SalesLine."Line No." :=
                            GetNextLineNo(SalesHeader);

                        SalesLine.Validate(
                            Type,
                            SalesLine.Type::Item);

                        SalesLine.Validate(
                            "No.",
                            CodeArticle);

                        SalesLine.Validate(
                            Quantity,
                            Quantite);

                        SalesLine.Validate(
                            "Unit Price",
                            PrixUnitaire);

                        SalesLine.Insert(true);
                    end;
                end

                // =====================================================
                // CAS 2 : L'article n'existe pas
                //         => créer article catalogue
                // =====================================================

                else begin

                    NonstockItem.Reset();

                    NonstockItem.SetRange(
                        "Entry No.",
                        CodeArticle);
                    if not NonstockItem.FindFirst() then begin

                        // ---------------------------------------------
                        // Créer l'article catalogue
                        // ---------------------------------------------

                        NonstockItem.Init();

                        NonstockItem."Entry No." :=
                            CodeArticle;

                        NonstockItem.Description :=
                            CodeArticle;

                        NonstockItem."Unit Price" :=
                            PrixUnitaire;

                        NonstockItem.Insert(false);
                    end else begin

                        // ---------------------------------------------
                        // Article catalogue déjà existant
                        // ---------------------------------------------

                        NonstockItem."Unit Price" :=
                            PrixUnitaire;
                        if NonstockItem.Description = '' then
                            NonstockItem.Description :=
                                CodeArticle;

                        NonstockItem.Modify(false);
                    end;

                    // =================================================
                    // IMPORTANT :
                    // Aucun vrai Article n'est créé ici.
                    //
                    // La création du vrai Article se fera dans
                    // 50101 lors de "Créer commande".
                    // =================================================

                    SalesLine.Reset();

                    SalesLine.SetRange(
                        "Document Type",
                        SalesHeader."Document Type");

                    SalesLine.SetRange(
                        "Document No.",
                        SalesHeader."No.");

                    SalesLine.SetRange(
                        "Catalog Item Entry No.",
                        CodeArticle);
                    if SalesLine.FindFirst() then begin

                        SalesLine.Description :=
                            NonstockItem.Description;

                        SalesLine."Catalog Item Entry No." :=
                            NonstockItem."Entry No.";

                        SalesLine.Nonstock :=
                            true;

                        SalesLine.Quantity :=
                            Quantite;

                        SalesLine."Unit Price" :=
                            PrixUnitaire;

                        SalesLine.Modify(true);
                    end else begin

                        SalesLine.Init();

                        SalesLine."Document Type" :=
                            SalesHeader."Document Type";

                        SalesLine."Document No." :=
                            SalesHeader."No.";

                        SalesLine."Line No." :=
                            GetNextLineNo(SalesHeader);

                        SalesLine.Type :=
                            SalesLine.Type::Item;

                        SalesLine.Description :=
                            NonstockItem.Description;

                        SalesLine."Catalog Item Entry No." :=
                            NonstockItem."Entry No.";

                        SalesLine.Nonstock :=
                            true;

                        SalesLine.Quantity :=
                            Quantite;

                        SalesLine."Unit Price" :=
                            PrixUnitaire;

                        SalesLine.Insert(true);
                    end;
                end;
            end;

            RowNo += 1;
        end;

        Message('Import du devis terminé.');
    end;


    local procedure GetNextLineNo(
        SalesHeader: Record "Sales Header"): Integer
    var
        SalesLine: Record "Sales Line";
    begin
        SalesLine.SetRange(
            "Document Type",
            SalesHeader."Document Type");

        SalesLine.SetRange(
            "Document No.",
            SalesHeader."No.");
        if SalesLine.FindLast() then
            exit(
                SalesLine."Line No." + 10000);

        exit(10000);
    end;


    local procedure GetCellText(
        var TempExcelBuffer: Record "Excel Buffer" temporary;
        RowNo: Integer;
        ColumnNo: Integer): Text
    begin
        TempExcelBuffer.Reset();

        TempExcelBuffer.SetRange(
            "Row No.",
            RowNo);

        TempExcelBuffer.SetRange(
            "Column No.",
            ColumnNo);
        if TempExcelBuffer.FindFirst() then
            exit(
                TempExcelBuffer."Cell Value as Text");

        exit('');
    end;


    local procedure GetCellValue(
        var TempExcelBuffer: Record "Excel Buffer" temporary;
        RowNo: Integer;
        ColumnNo: Integer): Code[20]
    var
        CellValue: Text;
    begin
        CellValue := GetCellText(
            TempExcelBuffer,
            RowNo,
            ColumnNo);

        exit(
            CopyStr(
                CellValue,
                1,
                20));
    end;


    local procedure GetDecimalValue(
        var TempExcelBuffer: Record "Excel Buffer" temporary;
        RowNo: Integer;
        ColumnNo: Integer): Decimal
    var
        CellValue: Text;
        DecimalValue: Decimal;
    begin
        CellValue := GetCellText(
            TempExcelBuffer,
            RowNo,
            ColumnNo);
        if CellValue = '' then
            exit(0);
        if Evaluate(
            DecimalValue,
            CellValue)
        then
            exit(DecimalValue);

        Error(
            'La valeur "%1" à la ligne %2 n''est pas un nombre valide.',
            CellValue,
            RowNo);
    end;


    procedure DownloadTemplate()
    var
        TempExcelBuffer: Record "Excel Buffer" temporary;
    begin
        TempExcelBuffer.CreateNewBook('Devis');

        TempExcelBuffer.NewRow();

        TempExcelBuffer.AddColumn(
            'Code article',
            false,
            '',
            true,
            false,
            false,
            '',
            TempExcelBuffer."Cell Type"::Text);

        TempExcelBuffer.AddColumn(
            'Quantité',
            false,
            '',
            true,
            false,
            false,
            '',
            TempExcelBuffer."Cell Type"::Number);

        TempExcelBuffer.AddColumn(
            'Prix unitaire',
            false,
            '',
            true,
            false,
            false,
            '',
            TempExcelBuffer."Cell Type"::Number);

        TempExcelBuffer.WriteSheet(
            'Devis',
            CompanyName,
            UserId);

        TempExcelBuffer.CloseBook();

        TempExcelBuffer.OpenExcel();
    end;
}