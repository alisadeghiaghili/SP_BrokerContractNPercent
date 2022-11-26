USE [BI]
GO
/****** Object:  StoredProcedure [Phi].[SP_BrokerContractNPercent]    Script Date: 23/11/2022 11:45:17 am ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--Declare @StartDate char(10),
--	    @EndDate char(10),
--		@NPercent int,
--		@BrokerCode int,
--		@BuyerSeller int,
--		@RingID int;

--set @StartDate = '1401/08/16';
--set @EndDate = '1401/08/16';
--set @BrokerCode = 130;
--set @NPercent = 20;
--set @BuyerSeller = 1;
--set @RingID = 2; --0:all

ALTER Procedure [Phi].[SP_BrokerContractNPercent] 
	@StartDate char(10),
	@EndDate char(10),
	@NPercent int,
	@BrokerCode int,
	@BuyerSeller int,
	@RingID int

As

Declare @Query As nvarchar(max)
Set @Query = N'
with main as (
SELECT Symbol.CommodityMainGroup_PersianName AS MainGroupName, 
       Symbol.CommodityGroup_PersianName GroupName, 
       Symbol.CommoditySubGroup_PersianName SubGroupName, 
	   Contract.Code AS ContractMainCode, 
       CustomerContract.CustomerContractDetailNumber AS ContractDetailCode, 
       Date.PersianDate AS ContractDate, 
       Symbol.Commodity_PersianName CommodityName, 
       Symbol.CommodityUnitMeasure_PersianName UnitWeight, 
	   CustomerContract.Quantity * Symbol.Commodity_ShipmentWeight /1000 as Weight,
       CustomerContract.Quantity AS Quantity, 
       Contract.Price AS Price, 
       Currency.PersianName AS Currency, 
       BuyerBroker.PersianName AS BuyerBrokerName, 
	   BuyerBroker.Broker_OriginalPK AS BuyerBrokerCode,
       SellerBroker.PersianName AS SellerBrokerName, 
	   SellerBroker.Broker_OriginalPK AS SellerBrokerCode,
       ContractKind.PersianName ContractType,
       DeliveryDate.PersianDate DeliverDate,
       Symbol.Producer_PersianName AS Producer, 
       SellerCustomer.Customer_Name AS SellerName, 
       ISNULL(DATEDIFF(d,SettlementDate.RealDate,FinalPaymentDate.RealDate), 0) AS SettlementDelay,
       BuyerCustomer.NationalID AS BuyerNationalID, 
       SellerCustomer.NationalID AS SellerNationalID, 
       CustomerContract.TotalPrice AS TotalValue, 
       Symbol.TradingSymbol Symbol, 
       BuyerCustomer.TypeName BuyerCustomerType,
	   BuyerCustomer.Name BuyerName,
       CLearingKind.Name SettlementType,
       SettlementDate.PersianDate AS SettlementDateLimit,
       Symbol.DeliveryPlace_PersianName AS DeliveryPlace, 
       SellerCustomer.Customer_OriginalPK AS SellerCode, 
       BuyerCustomer.Customer_OriginalPK AS BuyerCode, 
       CASE WHEN SuspendStatus_ID = 3 THEN N''انفساخ'' ELSE N''خیر'' END AS IsCanceled, 
       Contract.OfferItem_OriginalPK OfferID, 
       OfferKind.NAME AS OfferKind,
	   Ring.Name RingName 


FROM [Auction_DM].[Auction_Fact].[CustomerContract]
     INNER JOIN [Auction_DM].[Auction_Fact].Contract
		ON CustomerContract.Contract_ID = Contract.ID
     INNER JOIN Auction_DM.Auction_Fact.Offer
		ON Contract.Offer_ID = Offer.ID
     INNER JOIN Auction_DM.Auction_Dim.Ring r WITH(NOLOCK) 
		ON CustomerContract.Ring_ID = r.ID
     INNER JOIN Auction_DM.General_Dim.Date 
		ON Date.ID = CustomerContract.HallMatchingDate_ID
     LEFT JOIN Auction_DM.General_Dim.Date DeliveryDate 
		ON DeliveryDate.ID = Contract.HallMatchingDeliveryDate_ID
	 LEFT JOIN Auction_DM.General_Dim.Date FinalPaymentDate 
		ON FinalPaymentDate.ID = Contract.ContractFinalPaymentDate_ID
	 LEFT JOIN Auction_DM.General_Dim.Date SettlementDate 
		ON SettlementDate.ID = CustomerContract.AllowablePaymentDate_ID
     INNER JOIN Auction_DM.Auction_Dim.Symbol
		ON Symbol.ID = CustomerContract.Symbol_ID
     INNER JOIN Auction_DM.Auction_Dim.Customer BuyerCustomer 
		ON BuyerCustomer.ID = BuyerCustomer_ID
     INNER JOIN Auction_DM.Auction_Dim.Broker BuyerBroker 
		ON BuyerBroker.ID = CustomerContract.BuyerBroker_ID
     INNER JOIN Auction_DM.Auction_Dim.Supplier SellerCustomer 
		ON SellerCustomer.ID = CustomerContract.Supplier_ID
     INNER JOIN Auction_DM.Auction_Dim.Broker SellerBroker 
		ON SellerBroker.ID = CustomerContract.SellerBroker_ID
     INNER JOIN Auction_DM.Auction_Dim.ContractKind 
		ON ContractKind.id = CustomerContract.ContractKind_ID
     INNER JOIN Auction_DM.Auction_Dim.ContractStatus 
		ON ContractStatus.id = CustomerContract.ContractStatus_ID
     INNER JOIN Auction_DM.Auction_Dim.ClearingKind CLearingKind 
		ON CLearingKind.id = CustomerContract.ClearingKind_ID
     INNER JOIN Auction_DM.Auction_Dim.OfferKind 
		ON OfferKind.ID = Contract.OfferKind_ID
	 INNER JOIN Auction_DM.Auction_Dim.Currency 
		ON Currency.ID = Contract.Currency_ID
	 INNER JOIN Auction_DM.Auction_Dim.Ring 
		ON Ring.ID = Contract.Ring_ID
		
	'

Set @Query = @Query + concat('Where Date.PersianDate between ''', @StartDate, ''' and ''', @EndDate, '''')

If @RingID <> 0
	set @Query = @Query + ' And '  + concat('Ring.ID = ', @RingID)

set @Query = @Query + '), result as ('

If @BuyerSeller = 0
	
	Set @Query = @Query + concat('Select * 
	From main
	Where BuyerBrokerCode = ', @brokerCode)
Else
If @BuyerSeller = 1
	Set @Query = @Query + concat('Select * 
	From main
	Where SellerBrokerCode = ', @brokerCode)

Else 
If @BuyerSeller = 2
	Set @Query = @Query + Concat('
	Select * 
	From main
	Where BuyerBrokerCode = ', @brokerCode,
	' Union

	Select * 
	From main
	Where SellerBrokerCode = ', @brokerCode)

Set @Query = @Query + '),
resultGrouped as (
	SELECT *
	FROM (SELECT Row_Number()OVER(partition BY GroupName, SubGroupName Order by GroupName, SubGroupName) AS [RowNumber], *
        FROM Result) PartitionResult
WHERE  [RowNumber] = 1 
)
'

Set @Query = @Query + concat('select top(', @NPercent, ') Percent *
From resultGrouped')

set @Query = @Query + ' Go;'

select(@Query)
--Execute(@Query)
