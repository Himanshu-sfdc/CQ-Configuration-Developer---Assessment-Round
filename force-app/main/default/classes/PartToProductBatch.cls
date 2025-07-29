global class PartToProductBatch implements Database.Batchable<SObject>, Schedulable {

    global void execute(SchedulableContext sc) {
        Database.executeBatch(new PartToProductBatch(), 200);
    }

    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Name, Part_Number__c, Product__c
            FROM SQX_Part__c
            WHERE Active__c = true AND Product__c = null
        ]);
    }

    global void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<SQX_Part__c> parts = (List<SQX_Part__c>) scope;

        List<SQX_Part__c> partsToUpdate = new List<SQX_Part__c>();
        List<Product2> newProducts = new List<Product2>();
        Map<String, Product2> partKeyToProductMap = new Map<String, Product2>();

        Set<String> partNames = new Set<String>();
        Set<String> partNumbers = new Set<String>();
        Set<String> partKeys = new Set<String>();

        // Prepare for lookup
        for (SQX_Part__c part : parts) {
            if (String.isNotBlank(part.Name) && String.isNotBlank(part.Part_Number__c)) {
                partNames.add(part.Name);
                partNumbers.add(part.Part_Number__c);
                partKeys.add(part.Name + ':' + part.Part_Number__c);
            }
        }

        // Query existing products
        for (Product2 prod : [
            SELECT Id, Name, ProductCode
            FROM Product2
            WHERE Name IN :partNames AND ProductCode IN :partNumbers
        ]) {
            String key = prod.Name + ':' + prod.ProductCode;
            partKeyToProductMap.put(key, prod);
        }

        // Process parts
        for (SQX_Part__c part : parts) {
            String key = part.Name + ':' + part.Part_Number__c;
            if (partKeyToProductMap.containsKey(key)) {
                part.Product__c = partKeyToProductMap.get(key).Id;
                partsToUpdate.add(part);
            } else {
                Product2 newProd = new Product2(
                    Name = part.Name,
                    ProductCode = part.Part_Number__c,
                    IsActive = true
                );
                newProducts.add(newProd);
            }
        }

        if (!newProducts.isEmpty()) {
            insert newProducts;

            for (Product2 p : newProducts) {
                String key = p.Name + ':' + p.ProductCode;
                partKeyToProductMap.put(key, p);
            }

            for (SQX_Part__c part : parts) {
                String key = part.Name + ':' + part.Part_Number__c;
                if (partKeyToProductMap.containsKey(key)) {
                    part.Product__c = partKeyToProductMap.get(key).Id;
                    partsToUpdate.add(part);
                }
            }
        }

        if (!partsToUpdate.isEmpty()) {
            update partsToUpdate;
        }
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('Part to Product batch completed.');
    }
}