import FungibleToken from "../contracts/standard/FungibleToken.cdc"
import NonFungibleToken from "../contracts/standard/NonFungibleToken.cdc"
import FUSD from "../contracts/standard/FUSD.cdc"
import FiatToken from "../contracts/standard/FiatToken.cdc"
import FlowToken from "../contracts/standard/FlowToken.cdc"
import MetadataViews from "../contracts/standard/MetadataViews.cdc"
import FIND from "../contracts/FIND.cdc"
import FindPack from "../contracts/FindPack.cdc"
import Profile from "../contracts/Profile.cdc"
import FindMarket from "../contracts/FindMarket.cdc"
import FindMarketDirectOfferEscrow from "../contracts/FindMarketDirectOfferEscrow.cdc"
import Dandy from "../contracts/Dandy.cdc"
import FindThoughts from "../contracts/FindThoughts.cdc"
import FindLeaseMarketDirectOfferSoft from "../contracts/FindLeaseMarketDirectOfferSoft.cdc"
import FindLeaseMarket from "../contracts/FindLeaseMarket.cdc"

transaction(name: String) {
    prepare(account: AuthAccount) {
        //if we do not have a profile it might be stored under a different address so we will just remove it
        let profileCapFirst = account.getCapability<&{Profile.Public}>(Profile.publicPath)
        if profileCapFirst.check() {
            return 
        }
        //the code below has some dead code for this specific transaction, but it is hard to maintain otherwise
        //SYNC with register
        //Add exising FUSD or create a new one and add it
        let fusdReceiver = account.getCapability<&{FungibleToken.Receiver}>(/public/fusdReceiver)
        if !fusdReceiver.check() {
            let fusd <- FUSD.createEmptyVault()
            account.save(<- fusd, to: /storage/fusdVault)
            account.link<&FUSD.Vault{FungibleToken.Receiver}>( /public/fusdReceiver, target: /storage/fusdVault)
            account.link<&FUSD.Vault{FungibleToken.Balance}>( /public/fusdBalance, target: /storage/fusdVault)
        }

        let usdcCap = account.getCapability<&{FungibleToken.Receiver}>(FiatToken.VaultReceiverPubPath)
        if !usdcCap.check() {
            account.save( <-FiatToken.createEmptyVault(), to: FiatToken.VaultStoragePath)
            account.link<&FiatToken.Vault{FungibleToken.Receiver}>( FiatToken.VaultReceiverPubPath, target: FiatToken.VaultStoragePath)
            account.link<&FiatToken.Vault{FiatToken.ResourceId}>( FiatToken.VaultUUIDPubPath, target: FiatToken.VaultStoragePath)
            account.link<&FiatToken.Vault{FungibleToken.Balance}>( FiatToken.VaultBalancePubPath, target:FiatToken.VaultStoragePath)
        }

        let leaseCollection = account.getCapability<&FIND.LeaseCollection{FIND.LeaseCollectionPublic}>(FIND.LeasePublicPath)
        if !leaseCollection.check() {
            account.save(<- FIND.createEmptyLeaseCollection(), to: FIND.LeaseStoragePath)
            account.link<&FIND.LeaseCollection{FIND.LeaseCollectionPublic}>( FIND.LeasePublicPath, target: FIND.LeaseStoragePath)
        }

        let bidCollection = account.getCapability<&FIND.BidCollection{FIND.BidCollectionPublic}>(FIND.BidPublicPath)
        if !bidCollection.check() {
            account.save(<- FIND.createEmptyBidCollection(receiver: fusdReceiver, leases: leaseCollection), to: FIND.BidStoragePath)
            account.link<&FIND.BidCollection{FIND.BidCollectionPublic}>( FIND.BidPublicPath, target: FIND.BidStoragePath)
        }

        let dandyCap= account.getCapability<&{NonFungibleToken.CollectionPublic}>(Dandy.CollectionPublicPath)
        if !dandyCap.check() {
            account.save<@NonFungibleToken.Collection>(<- Dandy.createEmptyCollection(), to: Dandy.CollectionStoragePath)
            account.link<&Dandy.Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection, Dandy.CollectionPublic}>(
                Dandy.CollectionPublicPath,
                target: Dandy.CollectionStoragePath
            )
            account.link<&Dandy.Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection, Dandy.CollectionPublic}>(
                Dandy.CollectionPrivatePath,
                target: Dandy.CollectionStoragePath
            )
        }

        let thoughtsCap= account.getCapability<&{FindThoughts.CollectionPublic}>(FindThoughts.CollectionPublicPath)
        if !thoughtsCap.check() {
            account.save(<- FindThoughts.createEmptyCollection(), to: FindThoughts.CollectionStoragePath)
            account.link<&FindThoughts.Collection{FindThoughts.CollectionPublic , MetadataViews.ResolverCollection}>(
                FindThoughts.CollectionPublicPath,
                target: FindThoughts.CollectionStoragePath
            )
        }

        let findPackCap= account.getCapability<&{NonFungibleToken.CollectionPublic}>(FindPack.CollectionPublicPath)
        if !findPackCap.check() {
            account.save<@NonFungibleToken.Collection>( <- FindPack.createEmptyCollection(), to: FindPack.CollectionStoragePath)
            account.link<&FindPack.Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>(
                FindPack.CollectionPublicPath,
                target: FindPack.CollectionStoragePath
            )
        }

        var created=false
        var updated=false
        let profileCap = account.getCapability<&{Profile.Public}>(Profile.publicPath)
        if !profileCap.check() {
            let profile <-Profile.createUser(name:name, createdAt: "find")
            account.save(<-profile, to: Profile.storagePath)
            account.link<&Profile.User{Profile.Public}>(Profile.publicPath, target: Profile.storagePath)
            account.link<&{FungibleToken.Receiver}>(Profile.publicReceiverPath, target: Profile.storagePath)
            created=true
        }

        let profile=account.borrow<&Profile.User>(from: Profile.storagePath)!

        if !profile.hasWallet("Flow") {
            let flowWallet=Profile.Wallet( name:"Flow", receiver:account.getCapability<&{FungibleToken.Receiver}>(/public/flowTokenReceiver), balance:account.getCapability<&{FungibleToken.Balance}>(/public/flowTokenBalance), accept: Type<@FlowToken.Vault>(), tags: ["flow"])

            profile.addWallet(flowWallet)
            updated=true
        }
        if !profile.hasWallet("FUSD") {
            profile.addWallet(Profile.Wallet( name:"FUSD", receiver:fusdReceiver, balance:account.getCapability<&{FungibleToken.Balance}>(/public/fusdBalance), accept: Type<@FUSD.Vault>(), tags: ["fusd", "stablecoin"]))
            updated=true
        }

        if !profile.hasWallet("USDC") {
            profile.addWallet(Profile.Wallet( name:"USDC", receiver:usdcCap, balance:account.getCapability<&{FungibleToken.Balance}>(FiatToken.VaultBalancePubPath), accept: Type<@FiatToken.Vault>(), tags: ["usdc", "stablecoin"]))
            updated=true
        }

        //If find name not set and we have a profile set it.
        if profile.getFindName() == "" {
            if let findName = FIND.reverseLookup(account.address) {
                profile.setFindName(findName)
                // If name is set, it will emit Updated Event, there is no need to emit another update event below. 
                updated=false
            }
        }

        if created {
            profile.emitCreatedEvent()
        } else if updated {
            profile.emitUpdatedEvent()
        }

        let receiverCap=account.getCapability<&{FungibleToken.Receiver}>(Profile.publicReceiverPath)
        let tenantCapability= FindMarket.getTenantCapability(FindMarket.getFindTenantAddress())!

        let tenant = tenantCapability.borrow()!

        let doeSaleType= Type<@FindMarketDirectOfferEscrow.SaleItemCollection>()
        let doeSalePublicPath=FindMarket.getPublicPath(doeSaleType, name: tenant.name)
        let doeSaleStoragePath= FindMarket.getStoragePath(doeSaleType, name:tenant.name)
        let doeSaleCap= account.getCapability<&FindMarketDirectOfferEscrow.SaleItemCollection{FindMarketDirectOfferEscrow.SaleItemCollectionPublic, FindMarket.SaleItemCollectionPublic}>(doeSalePublicPath) 
        if !doeSaleCap.check() {
            account.save<@FindMarketDirectOfferEscrow.SaleItemCollection>(<- FindMarketDirectOfferEscrow.createEmptySaleItemCollection(tenantCapability), to: doeSaleStoragePath)
            account.link<&FindMarketDirectOfferEscrow.SaleItemCollection{FindMarketDirectOfferEscrow.SaleItemCollectionPublic, FindMarket.SaleItemCollectionPublic}>(doeSalePublicPath, target: doeSaleStoragePath)
        }

        //TODO: we might need to create a transactions users run before people can bid on their leases?
        let leaseTenant=tenant
        let leaseTenantCapability=tenantCapability
        let leaseDOSSaleItemType= Type<@FindLeaseMarketDirectOfferSoft.SaleItemCollection>()
        let leaseDOSPublicPath=leaseTenant.getPublicPath(leaseDOSSaleItemType)
        let leaseDOSStoragePath= leaseTenant.getStoragePath(leaseDOSSaleItemType)
        let leaseDOSSaleItemCap= account.getCapability<&FindLeaseMarketDirectOfferSoft.SaleItemCollection{FindLeaseMarketDirectOfferSoft.SaleItemCollectionPublic, FindLeaseMarket.SaleItemCollectionPublic}>(leaseDOSPublicPath)
        if !leaseDOSSaleItemCap.check() {
            //The link here has to be a capability not a tenant, because it can change.
            account.save<@FindLeaseMarketDirectOfferSoft.SaleItemCollection>(<- FindLeaseMarketDirectOfferSoft.createEmptySaleItemCollection(leaseTenantCapability), to: leaseDOSStoragePath)
            account.link<&FindLeaseMarketDirectOfferSoft.SaleItemCollection{FindLeaseMarketDirectOfferSoft.SaleItemCollectionPublic, FindLeaseMarket.SaleItemCollectionPublic}>(leaseDOSPublicPath, target: leaseDOSStoragePath)
        }


        //SYNC with register

    }
}
