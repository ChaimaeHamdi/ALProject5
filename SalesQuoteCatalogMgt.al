codeunit 50101 "Sales Quote Catalog Mgt."
{
    EventSubscriberInstance = StaticAutomatic;

    procedure ConvertQuoteToOrder(var QuoteHeader: Record "Sales Header")
    var
        SalesQuoteToOrder: Codeunit "Sales-Quote to Order";
        OrderHeader: Record "Sales Header";
    begin
        QuoteHeader.TestField(
            "Document Type",
            QuoteHeader."Document Type"::Quote);

        QuoteHeader.TestField(
            Status,
            QuoteHeader.Status::Open);

        ConvertCatalogItems(QuoteHeader);

        SalesQuoteToOrder.Run(QuoteHeader);
        SalesQuoteToOrder.GetSalesOrderHeader(OrderHeader);

        Commit();

        Page.Run(
            Page::"Sales Order",
            OrderHeader);
    end;

    local procedure ConvertCatalogItems(
        var QuoteHeader: Record "Sales Header")
    var
        SalesLine: Record "Sales Line";
        CatalogItem: Record "Nonstock Item";
        Item: Record Item;
        SalesSetup: Record "Sales & Receivables Setup";
        ItemTemplMgt: Codeunit "Item Templ. Mgt.";
        IsHandled: Boolean;
        ItemNo: Code[20];
        Quantity: Decimal;
        UnitPrice: Decimal;
    begin
        SalesLine.Reset();
        SalesLine.SetRange(
            "Document Type",
            QuoteHeader."Document Type");
        SalesLine.SetRange(
            "Document No.",
            QuoteHeader."No.");
        SalesLine.SetFilter(
            "Catalog Item Entry No.",
            '<>%1',
            '');
        if SalesLine.FindSet(false) then
            repeat
                if not CatalogItem.Get(
                    SalesLine."Catalog Item Entry No.")
                then
                    Error(
                        'L''article catalogue %1 associé à la ligne %2 est introuvable.',
                        SalesLine."Catalog Item Entry No.",
                        SalesLine."Line No.");

                ItemNo := CatalogItem."Item No.";
                if (ItemNo = '') or not Item.Get(ItemNo) then begin
                    if not SalesSetup.Get() then
                        Error('Les paramètres ventes ne sont pas configurés.');

                    SalesSetup.TestField(
                        "Default Catalog Item Template");

                    Clear(Item);

                    IsHandled := false;
                    if not ItemTemplMgt.CreateItemFromTemplate(
                        Item,
                        IsHandled,
                        SalesSetup."Default Catalog Item Template")
                    then
                        Error(
                            'La création de l''article pour le catalogue %1 a été annulée.',
                            CatalogItem."Entry No.");

                    ItemNo := Item."No.";
                    if ItemNo = '' then
                        Error(
                            'Le modèle n''a pas attribué de numéro d''article pour le catalogue %1.',
                            CatalogItem."Entry No.");

                    Item.Description := CatalogItem.Description;
                    Item."Auto Created" := true;
                    Item.Modify(true);
                end;
                if CatalogItem."Item No." <> ItemNo then begin
                    CatalogItem."Item No." := ItemNo;
                    CatalogItem.Modify(false);
                end;

                Quantity := SalesLine.Quantity;
                UnitPrice := SalesLine."Unit Price";

                SalesLine.Validate(
                    Type,
                    SalesLine.Type::Item);

                SalesLine.Nonstock := false;

                SalesLine.Validate(
                    "No.",
                    ItemNo);

                SalesLine.Description := CatalogItem.Description;

                SalesLine.Validate(
                    Quantity,
                    Quantity);

                SalesLine.Validate(
                    "Unit Price",
                    UnitPrice);

                SalesLine.Modify(true);
            until SalesLine.Next() = 0;
    end;

    procedure ValidateSalesOrder(
        var SalesHeader: Record "Sales Header")
    var
        WarehouseRequest: Record "Warehouse Request";
        WarehouseShipmentHeader: Record "Warehouse Shipment Header";
        WarehouseShipmentLine: Record "Warehouse Shipment Line";
        WarehouseShipmentNos: List of [Code[20]];
        WarehouseShipmentsToPost: List of [Code[20]];
        WarehouseShipmentNo: Code[20];
        ReleaseSalesDocument: Codeunit "Release Sales Document";
        GetSourceDocOutbound: Codeunit "Get Source Doc. Outbound";
        WhsePostShipment: Codeunit "Whse.-Post Shipment";
        SalesPost: Codeunit "Sales-Post";
    begin
        SalesHeader.TestField(
            "Document Type",
            SalesHeader."Document Type"::Order);

        SalesHeader.TestField("No.");
        if SalesHeader.Status = SalesHeader.Status::Open then
            ReleaseSalesDocument.Run(SalesHeader);

        SalesHeader.Get(
            SalesHeader."Document Type",
            SalesHeader."No.");

        WarehouseShipmentLine.Reset();
        WarehouseShipmentLine.SetRange(
            "Source Type",
            Database::"Sales Line");
        WarehouseShipmentLine.SetRange(
            "Source Subtype",
            SalesHeader."Document Type");
        WarehouseShipmentLine.SetRange(
            "Source No.",
            SalesHeader."No.");
        if WarehouseShipmentLine.FindSet() then
            repeat
                if not WarehouseShipmentNos.Contains(WarehouseShipmentLine."No.") then
                    WarehouseShipmentNos.Add(WarehouseShipmentLine."No.");
            until WarehouseShipmentLine.Next() = 0;
        if WarehouseShipmentNos.Count = 0 then begin
            WarehouseRequest.Reset();
            WarehouseRequest.SetRange(
                Type,
                WarehouseRequest.Type::Outbound);
            WarehouseRequest.SetRange(
                "Source Type",
                Database::"Sales Line");
            WarehouseRequest.SetRange(
                "Source Document",
                WarehouseRequest."Source Document"::"Sales Order");
            WarehouseRequest.SetRange(
                "Source No.",
                SalesHeader."No.");
            if not WarehouseRequest.FindSet() then begin
                SalesHeader.Ship := true;
                SalesHeader.Invoice := true;
                SalesPost.Run(SalesHeader);
                exit;
            end;
            repeat
                if not GetSourceDocOutbound.CreateWhseShipmentHeaderFromWhseRequest(
                    WarehouseRequest)
                then
                    Error(
                        'Impossible de créer l''expédition entrepôt pour la commande %1.',
                        SalesHeader."No.");
            until WarehouseRequest.Next() = 0;

            WarehouseShipmentLine.Reset();
            WarehouseShipmentLine.SetRange(
                "Source Type",
                Database::"Sales Line");
            WarehouseShipmentLine.SetRange(
                "Source Subtype",
                SalesHeader."Document Type");
            WarehouseShipmentLine.SetRange(
                "Source No.",
                SalesHeader."No.");
            if WarehouseShipmentLine.FindSet() then
                repeat
                    if not WarehouseShipmentNos.Contains(WarehouseShipmentLine."No.") then
                        WarehouseShipmentNos.Add(WarehouseShipmentLine."No.");
                until WarehouseShipmentLine.Next() = 0;
        end;
        if WarehouseShipmentNos.Count = 0 then
            Error(
                'Aucune ligne d''expédition entrepôt n''a été créée pour la commande %1.',
                SalesHeader."No.");
        foreach WarehouseShipmentNo in WarehouseShipmentNos do
            PrepareWarehouseShipmentForPosting(
                SalesHeader."No.",
                WarehouseShipmentNo);

        WarehouseShipmentLine.Reset();
        WarehouseShipmentLine.SetRange(
            "Source Type",
            Database::"Sales Line");
        WarehouseShipmentLine.SetRange(
            "Source Subtype",
            SalesHeader."Document Type");
        WarehouseShipmentLine.SetRange(
            "Source No.",
            SalesHeader."No.");
        if not WarehouseShipmentLine.FindSet() then
            Error(
                'Aucune ligne d''expédition entrepôt n''a été trouvée pour la commande %1.',
                SalesHeader."No.");

        WarehouseShipmentLine.Reset();
        WarehouseShipmentLine.SetRange(
            "Source Type",
            Database::"Sales Line");
        WarehouseShipmentLine.SetRange(
            "Source Subtype",
            SalesHeader."Document Type");
        WarehouseShipmentLine.SetRange(
            "Source No.",
            SalesHeader."No.");
        WarehouseShipmentLine.SetFilter(
            "Qty. to Ship",
            '>0');
        if WarehouseShipmentLine.FindSet() then
            repeat
                if WarehouseShipmentLine."Qty. to Ship" > 0 then
                    if not WarehouseShipmentsToPost.Contains(WarehouseShipmentLine."No.") then
                        WarehouseShipmentsToPost.Add(WarehouseShipmentLine."No.");
            until WarehouseShipmentLine.Next() = 0;
        if WarehouseShipmentsToPost.Count = 0 then
            Error(
                'Aucune quantité à expédier n''a été préparée pour la commande %1.',
                SalesHeader."No.");
        foreach WarehouseShipmentNo in WarehouseShipmentsToPost do begin
            SetWarehouseShipmentQtyToShip(
                SalesHeader,
                WarehouseShipmentLine,
                WarehouseShipmentNo);
            ValidateWarehousePreparation(WarehouseShipmentNo);

            WarehouseShipmentLine.Reset();
            WarehouseShipmentLine.SetRange(
                "No.",
                WarehouseShipmentNo);
            WarehouseShipmentLine.SetRange(
                "Source Type",
                Database::"Sales Line");
            WarehouseShipmentLine.SetRange(
                "Source Subtype",
                SalesHeader."Document Type");
            WarehouseShipmentLine.SetRange(
                "Source No.",
                SalesHeader."No.");
            WarehouseShipmentLine.SetFilter(
                "Qty. to Ship",
                '>0');
            if WarehouseShipmentLine.FindSet(true) then
                WhsePostShipment.Run(WarehouseShipmentLine);
        end;

        SalesHeader.Get(
            SalesHeader."Document Type",
            SalesHeader."No.");

        InitializeSalesLinesForInvoicing(SalesHeader);

        SalesHeader.Get(
            SalesHeader."Document Type",
            SalesHeader."No.");

        SalesHeader.Ship := false;
        SalesHeader.Invoice := true;

        SalesPost.Run(SalesHeader);
    end;

    local procedure PrepareWarehouseShipmentForPosting(
        SalesOrderNo: Code[20];
        WarehouseShipmentNo: Code[20])
    var
        Location: Record Location;
        WarehouseShipmentHeader: Record "Warehouse Shipment Header";
        WarehouseShipmentLine: Record "Warehouse Shipment Line";
        WhseShipmentRelease: Codeunit "Whse.-Shipment Release";
    begin
        WarehouseShipmentHeader.Get(WarehouseShipmentNo);
        if WarehouseShipmentHeader.Status = WarehouseShipmentHeader.Status::Open then
            WhseShipmentRelease.Release(WarehouseShipmentHeader);

        SetSalesOrderShipmentLineFilters(
            WarehouseShipmentLine,
            SalesOrderNo,
            WarehouseShipmentNo);
        if WarehouseShipmentLine.FindSet(true) then
            repeat
                if Location.Get(WarehouseShipmentLine."Location Code") then
                    if Location."Require Pick" then begin
                        WarehouseShipmentLine.SetHideValidationDialog(true);
                        WarehouseShipmentLine.CreatePickDoc(
                            WarehouseShipmentLine,
                            WarehouseShipmentHeader);
                    end;
            until WarehouseShipmentLine.Next() = 0;
        FillPickQuantitiesToHandle(WarehouseShipmentNo);
        RegisterWarehouseShipmentPicks(WarehouseShipmentNo);
    end;

    local procedure SetSalesOrderShipmentLineFilters(
        var WarehouseShipmentLine: Record "Warehouse Shipment Line";
        SalesOrderNo: Code[20];
        WarehouseShipmentNo: Code[20])
    begin
        WarehouseShipmentLine.Reset();
        WarehouseShipmentLine.SetRange(
            "No.",
            WarehouseShipmentNo);
        WarehouseShipmentLine.SetRange(
            "Source Type",
            Database::"Sales Line");
        WarehouseShipmentLine.SetRange(
            "Source Subtype",
            Enum::"Sales Document Type"::Order);
        WarehouseShipmentLine.SetRange(
            "Source No.",
            SalesOrderNo);
    end;

    local procedure SetWarehouseShipmentQtyToShip(
        var SalesHeader: Record "Sales Header";
        var WarehouseShipmentLine: Record "Warehouse Shipment Line";
        WarehouseShipmentNo: Code[20])
    var
        Location: Record Location;
        QtyToShip: Decimal;
    begin
        WarehouseShipmentLine.Reset();
        WarehouseShipmentLine.SetRange(
            "Source Type",
            Database::"Sales Line");
        WarehouseShipmentLine.SetRange(
            "Source Subtype",
            SalesHeader."Document Type");
        WarehouseShipmentLine.SetRange(
            "Source No.",
            SalesHeader."No.");
        WarehouseShipmentLine.SetRange(
            "No.",
            WarehouseShipmentNo);
        if WarehouseShipmentLine.FindSet(true) then
            repeat
                QtyToShip := WarehouseShipmentLine."Qty. Outstanding";
                if Location.Get(WarehouseShipmentLine."Location Code") then
                    if Location."Require Pick" then
                        QtyToShip := WarehouseShipmentLine."Qty. Picked";

                if QtyToShip > WarehouseShipmentLine."Qty. Outstanding" then
                    QtyToShip := WarehouseShipmentLine."Qty. Outstanding";

                if WarehouseShipmentLine."Qty. to Ship" <> QtyToShip then begin
                    WarehouseShipmentLine.Validate("Qty. to Ship", QtyToShip);
                    WarehouseShipmentLine.Modify(true);
                end;
            until WarehouseShipmentLine.Next() = 0;
    end;

    local procedure FillPickQuantitiesToHandle(
        WarehouseShipmentNo: Code[20])
    var
        WarehouseActivityLine: Record "Warehouse Activity Line";
    begin
        WarehouseActivityLine.Reset();
        WarehouseActivityLine.SetRange(
            "Activity Type",
            WarehouseActivityLine."Activity Type"::Pick);
        WarehouseActivityLine.SetRange(
            "Whse. Document Type",
            WarehouseActivityLine."Whse. Document Type"::Shipment);
        WarehouseActivityLine.SetRange(
            "Whse. Document No.",
            WarehouseShipmentNo);
        if WarehouseActivityLine.FindSet(true) then
            repeat
                if (WarehouseActivityLine."Qty. to Handle" = 0) and
                   (WarehouseActivityLine."Qty. Outstanding" > 0)
                then begin
                    WarehouseActivityLine.Validate(
                        "Qty. to Handle",
                        WarehouseActivityLine."Qty. Outstanding");
                    WarehouseActivityLine.Modify(true);
                end;
            until WarehouseActivityLine.Next() = 0;
    end;

    local procedure RegisterWarehouseShipmentPicks(
        WarehouseShipmentNo: Code[20])
    var
        WarehouseActivityLine: Record "Warehouse Activity Line";
        WarehouseActivityNos: List of [Code[20]];
        WarehouseActivityNo: Code[20];
        WhseActivityRegister: Codeunit "Whse.-Activity-Register";
    begin
        WarehouseActivityLine.Reset();
        WarehouseActivityLine.SetRange(
            "Activity Type",
            WarehouseActivityLine."Activity Type"::Pick);
        WarehouseActivityLine.SetRange(
            "Whse. Document Type",
            WarehouseActivityLine."Whse. Document Type"::Shipment);
        WarehouseActivityLine.SetRange(
            "Whse. Document No.",
            WarehouseShipmentNo);
        if WarehouseActivityLine.FindSet() then
            repeat
                if not WarehouseActivityNos.Contains(WarehouseActivityLine."No.") then
                    WarehouseActivityNos.Add(WarehouseActivityLine."No.");
            until WarehouseActivityLine.Next() = 0;
        if WarehouseActivityNos.Count = 0 then
            exit;
        foreach WarehouseActivityNo in WarehouseActivityNos do begin
            WarehouseActivityLine.Reset();
            WarehouseActivityLine.SetRange(
                "No.",
                WarehouseActivityNo);
            WarehouseActivityLine.SetRange(
                "Activity Type",
                WarehouseActivityLine."Activity Type"::Pick);
            if WarehouseActivityLine.FindFirst() then
                WhseActivityRegister.Run(WarehouseActivityLine);
        end;
    end;

    local procedure ValidateWarehousePreparation(
        WarehouseShipmentNo: Code[20])
    var
        Location: Record Location;
        WarehouseShipmentLine: Record "Warehouse Shipment Line";
        WarehouseActivityLine: Record "Warehouse Activity Line";
    begin
        WarehouseShipmentLine.Reset();
        WarehouseShipmentLine.SetRange(
            "No.",
            WarehouseShipmentNo);

        if WarehouseShipmentLine.FindSet() then
            repeat
                if Location.Get(WarehouseShipmentLine."Location Code") then begin
                    if (WarehouseShipmentLine."Qty. Outstanding" > 0) and
                       (WarehouseShipmentLine."Qty. to Ship" = 0)
                    then
                        Error(
                            'Expédition %1, article %2, emplacement %3 : Qty. Outstanding=%4, Qty. Picked=%5, Qty. to Ship=%6. Vérifier le stock disponible dans un bin prélevable et le prélèvement enregistré.',
                            WarehouseShipmentLine."No.",
                            WarehouseShipmentLine."Item No.",
                            WarehouseShipmentLine."Location Code",
                            WarehouseShipmentLine."Qty. Outstanding",
                            WarehouseShipmentLine."Qty. Picked",
                            WarehouseShipmentLine."Qty. to Ship");
                end;
            until WarehouseShipmentLine.Next() = 0;

        WarehouseActivityLine.Reset();
        WarehouseActivityLine.SetRange(
            "Whse. Document Type",
            WarehouseActivityLine."Whse. Document Type"::Shipment);
        WarehouseActivityLine.SetRange(
            "Whse. Document No.",
            WarehouseShipmentNo);
        WarehouseActivityLine.SetRange(
            "Activity Type",
            WarehouseActivityLine."Activity Type"::Pick);

        if WarehouseActivityLine.FindSet() then
            repeat
                if (WarehouseActivityLine."Qty. Outstanding" > 0) and
                   (WarehouseActivityLine."Qty. to Handle" = 0)
                then
                    Error(
                        'Pick %1 pour expédition %2 : Qty. Outstanding=%3, Qty. to Handle=%4. Le prélèvement n''a pas été préparé.',
                        WarehouseActivityLine."No.",
                        WarehouseShipmentNo,
                        WarehouseActivityLine."Qty. Outstanding",
                        WarehouseActivityLine."Qty. to Handle");
            until WarehouseActivityLine.Next() = 0;
    end;

    local procedure InitializeSalesLinesForInvoicing(
        var SalesHeader: Record "Sales Header")
    var
        SalesLine: Record "Sales Line";
        QtyToInvoice: Decimal;
        HasQtyToInvoice: Boolean;
    begin
        SalesLine.Reset();
        SalesLine.SetRange(
            "Document Type",
            SalesHeader."Document Type");
        SalesLine.SetRange(
            "Document No.",
            SalesHeader."No.");
        if SalesLine.FindSet(true) then
            repeat
                if SalesLine.Type <> SalesLine.Type::" " then begin
                    QtyToInvoice := SalesLine."Qty. Shipped Not Invoiced";
                    if QtyToInvoice <> 0 then begin
                        SalesLine.Validate(
                            "Qty. to Invoice",
                            QtyToInvoice);
                        SalesLine.Modify(true);
                        HasQtyToInvoice := true;
                    end;
                end;
            until SalesLine.Next() = 0;
        if not HasQtyToInvoice then
            Error(
                'La commande %1 ne contient aucune quantité expédiée restant à facturer.',
                SalesHeader."No.");
    end;

    [EventSubscriber(
        ObjectType::Codeunit,
        Codeunit::"Sales-Post (Yes/No)",
        'OnBeforeConfirmSalesPost',
        '',
        false,
        false)]
    local procedure OnBeforeConfirmSalesPost(
        var SalesHeader: Record "Sales Header";
        var HideDialog: Boolean;
        var IsHandled: Boolean;
        var DefaultOption: Integer;
        var PostAndSend: Boolean)
    var
        SelectedOption: Integer;
    begin
        if SalesHeader."Document Type" <> SalesHeader."Document Type"::Order then
            exit;

        if PostAndSend then
            exit;

        DefaultOption := 0;

        SelectedOption := StrMenu(
            'Expédier et facturer',
            0,
            'Validation de commande');

        if SelectedOption <> 1 then begin
            HideDialog := true;
            IsHandled := true;
            exit;
        end;

        HideDialog := true;
        IsHandled := true;

        ValidateSalesOrder(SalesHeader);
    end;
}