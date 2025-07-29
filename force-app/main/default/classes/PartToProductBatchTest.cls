@isTest
private class PartToProductBatchTest {

    // Utility method to create test Part
   private static SQX_Part__c createTestPart(String name, String partNumber, Boolean active) {
    return new SQX_Part__c(
        Name = name,
        Part_Number__c = partNumber,
        Active__c = active
    );
}



    @isTest
    static void testBatch_CreatesNewProduct() {
        // Create a part that has no matching Product2
        SQX_Part__c part = createTestPart('TestPart1', 'TP001', true);
        insert part;

        Test.startTest();
        PartToProductBatch batch = new PartToProductBatch();
        Database.executeBatch(batch, 1);
        Test.stopTest();

        part = [SELECT Product__c FROM SQX_Part__c WHERE Id = :part.Id];
        System.assertNotEquals(null, part.Product__c, 'Part should have Product__c populated after batch');
        
        Product2 prod = [SELECT Id, Name, ProductCode, IsActive FROM Product2 WHERE Id = :part.Product__c];
        System.assertEquals('TestPart1', prod.Name);
        System.assertEquals('TP001', prod.ProductCode);
        System.assertEquals(true, prod.IsActive);
    }

    @isTest
    static void testBatch_UsesExistingProduct() {
        // Create a product beforehand
        Product2 existingProduct = new Product2(
            Name = 'TestPart2',
            ProductCode = 'TP002',
            IsActive = true
        );
        insert existingProduct;

        // Create a matching Part
        SQX_Part__c part = createTestPart('TestPart2', 'TP002', true);
        insert part;

        Test.startTest();
        Database.executeBatch(new PartToProductBatch(), 1);
        Test.stopTest();

        part = [SELECT Product__c FROM SQX_Part__c WHERE Id = :part.Id];
        System.assertEquals(existingProduct.Id, part.Product__c, 'Part should be linked to the existing Product');
    }

    @isTest
    static void testScheduledBatchExecution() {
        Test.startTest();
        String cronExp = '0 0 6 * * ?';
        System.schedule('Test Scheduled Batch', cronExp, new PartToProductBatch());
        Test.stopTest();

        // We can't assert the batch ran, but no exceptions = success
        System.assert(true, 'Scheduled job submitted successfully.');
    }
}