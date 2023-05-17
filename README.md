TODOs:
1. Create PropertyNFT contract
2. Create SoulboundToken contract 
3. Create RentContract

4. Create IdentityVerification contract


 1. amountOfDeposit; // change to depositAmount X
 2. RentApplication // change to RentContract X
 4. Change RentContract rentapplicationId to id X
 3. Change Property struct - Tenant tenant to RentContract rentContract X
 6. We can delete:
 enum PropertyStatus {
        Rented,
        Vacant
    }
if a Property has RentContract it is rented, if not it is vacant. X
7. Add rentContractsAccepted counter. X
8. Dont delete Property (delete this function). Use EnumerableSet X

