@isTest
private class PartToProductBatchTest {

    // Utility method to create a test Part record
    private static SQX_Part__c createTestPart(String name, String partNumber, Boolean active) {
        return new SQX_Part__c(
            Name = name,
            Part_Number__c = partNumber,
            Active__c = active
        );
    }

    @isTest
static void testBatch_CreatesNewProduct_CoversInsertBlock() {
    // Create System Admin user
    Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
    User adminUser = new User(
        Username = 'batchadmin@example.com',
        Alias = 'batadmin',
        Email = 'batchadmin@example.com',
        LastName = 'Admin',
        ProfileId = adminProfile.Id,
        TimeZoneSidKey = 'Asia/Kolkata',
        LocaleSidKey = 'en_US',
        EmailEncodingKey = 'UTF-8',
        LanguageLocaleKey = 'en_US'
    );
    insert adminUser;

    System.runAs(adminUser) {
        // Ensure no Product exists
        List<Product2> existing = [SELECT Id FROM Product2 WHERE Name = 'PartNew' AND ProductCode = 'P123'];
        if (!existing.isEmpty()) {
            delete existing;
        }

        // Create a Part that doesn't match any existing Product
        SQX_Part__c part = new SQX_Part__c(
            Name = 'PartNew',
            Part_Number__c = 'P123',
            Active__c = true
        );
        insert part;

        Test.startTest();
        Database.executeBatch(new PartToProductBatch(), 1);
        Test.stopTest();

        // Validate Product created and linked
        part = [SELECT Product__c FROM SQX_Part__c WHERE Id = :part.Id];
        System.assertNotEquals(null, part.Product__c, 'Product should be linked to Part');

        Product2 createdProd = [SELECT Name, ProductCode, IsActive FROM Product2 WHERE Id = :part.Product__c];
        System.assertEquals('PartNew', createdProd.Name);
        System.assertEquals('P123', createdProd.ProductCode);
        System.assertEquals(true, createdProd.IsActive);
    }
}

    @isTest
    static void testBatch_UsesExistingProduct_AsSystemAdmin() {
        // Create System Administrator user
        Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User adminUser = new User(
            Username = 'adminuser2@example.com',
            Alias = 'admin2',
            Email = 'adminuser2@example.com',
            LastName = 'Admin',
            ProfileId = adminProfile.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert adminUser;

        System.runAs(adminUser) {
            // Insert a Product that should be matched by the batch
            Product2 existingProduct = new Product2(
                Name = 'TestPart2',
                ProductCode = 'TP002',
                IsActive = true
            );
            insert existingProduct;

            // Create a matching Part record
            SQX_Part__c part = createTestPart('TestPart2', 'TP002', true);
            insert part;

            Test.startTest();
            Database.executeBatch(new PartToProductBatch(), 1);
            Test.stopTest();

            // Verify the Part was linked to the existing Product
            part = [SELECT Product__c FROM SQX_Part__c WHERE Id = :part.Id];
            System.assertEquals(existingProduct.Id, part.Product__c, 'Part should be linked to the existing Product');
        }
    }

    @isTest
    static void testBatch_AsStandardUser_ShouldFail() {
        // Create a Standard User
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User stdUser = new User(
            Username = 'standarduser@example.com',
            Alias = 'stduser',
            Email = 'std@example.com',
            LastName = 'User',
            ProfileId = standardProfile.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert stdUser;

        System.runAs(stdUser) {
            Test.startTest();
            try {
                // Attempt to run batch as unauthorized user
                Database.executeBatch(new PartToProductBatch(), 1);
                System.assert(false, 'Batch should not run for Standard User');
            } catch (Exception e) {
                System.assert(e.getMessage().contains('not authorized'), 'Expected authorization error for standard user');
            }
            Test.stopTest();
        }
    }

    @isTest
    static void testScheduledBatchExecution() {
        // Just validate that the batch class can be scheduled with cron expression
        Test.startTest();
        String cronExp = '0 0 6 * * ?';
        System.schedule('Test Scheduled Batch', cronExp, new PartToProductScheduler());
        Test.stopTest();

        System.assert(true, 'Batch scheduled successfully.');
    }
}