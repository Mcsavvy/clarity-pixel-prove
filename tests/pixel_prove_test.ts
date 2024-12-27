import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Can mint a new photo NFT",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const block = chain.mineBlock([
            Tx.contractCall('pixel_prove', 'mint-photo', [
                types.utf8("Sunset at Beach"),
                types.utf8("Canon EOS R5"),
                types.utf8("Malibu, CA"),
                types.utf8("f/2.8, 1/1000, ISO 100"),
                types.uint(10)  // 10% royalty
            ], deployer.address)
        ]);
        
        block.receipts[0].result.expectOk().expectUint(1);
        
        const photoDetails = chain.callReadOnlyFn(
            'pixel_prove',
            'get-photo-details',
            [types.uint(1)],
            deployer.address
        );
        
        const metadata = photoDetails.result.expectOk().expectSome();
        assertEquals(metadata['photographer'], deployer.address);
        assertEquals(metadata['title'], "Sunset at Beach");
    }
});

Clarinet.test({
    name: "Can list and buy a photo",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const buyer = accounts.get('wallet_1')!;
        
        // First mint a photo
        let block = chain.mineBlock([
            Tx.contractCall('pixel_prove', 'mint-photo', [
                types.utf8("Mountain Lake"),
                types.utf8("Sony A7III"),
                types.utf8("Yosemite, CA"),
                types.utf8("f/4, 1/500, ISO 200"),
                types.uint(10)
            ], deployer.address)
        ]);
        
        const tokenId = block.receipts[0].result.expectOk().expectUint(1);
        
        // List the photo for sale
        block = chain.mineBlock([
            Tx.contractCall('pixel_prove', 'list-for-sale', [
                types.uint(tokenId),
                types.uint(1000)  // Price: 1000 STX
            ], deployer.address)
        ]);
        
        block.receipts[0].result.expectOk().expectBool(true);
        
        // Buy the photo
        block = chain.mineBlock([
            Tx.contractCall('pixel_prove', 'buy-photo', [
                types.uint(tokenId)
            ], buyer.address)
        ]);
        
        block.receipts[0].result.expectOk().expectBool(true);
        
        // Verify new owner
        const newOwner = chain.callReadOnlyFn(
            'pixel_prove',
            'get-owner',
            [types.uint(tokenId)],
            deployer.address
        );
        
        assertEquals(newOwner.result.expectSome(), buyer.address);
    }
});