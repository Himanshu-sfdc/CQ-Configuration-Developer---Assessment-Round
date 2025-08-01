// Batch class to sync active Parts with Products and optionally schedule it
global class PartToProductBatch implements Database.Batchable<SObject>, Schedulable {
    
    // Method to execute the batch via scheduler
    global void execute(SchedulableContext sc) {
        // Execute the batch job with batch size 200
        Database.executeBatch(new PartToProductBatch(), 200);
    }
    
    // Start method for batch: returns the records to process
    global Database.QueryLocator start(Database.BatchableContext bc) {
        // Query active Part records without an associated Product
        return Database.getQueryLocator([
            SELECT Id, Name, Part_Number__c, Product__c
            FROM SQX_Part__c
            WHERE Active__c = true AND Product__c = null
        ]);
    }
    
    // Execute method: processes each batch of Part records
    global void execute(Database.BatchableContext bc, List<SObject> scope) {
        // Cast the incoming SObject list to the custom Part object
        List<SQX_Part__c> parts = (List<SQX_Part__c>) scope;
        
        // Prepare lists and maps for processing
        List<SQX_Part__c> partsToUpdate = new List<SQX_Part__c>();       // List of Part records to update
        List<Product2> newProducts = new List<Product2>();               // Products to be inserted
        Map<String, Product2> partKeyToProductMap = new Map<String, Product2>(); // Map to hold existing or new Products by a unique key
        
        // Sets to hold unique names, numbers, and key combinations
        Set<String> partNames = new Set<String>();
        Set<String> partNumbers = new Set<String>();
        Set<String> partKeys = new Set<String>();
        
        // Loop through Parts and collect identifying fields
        for (SQX_Part__c part : parts) {
            if (String.isNotBlank(part.Name) && String.isNotBlank(part.Part_Number__c)) {
                partNames.add(part.Name);
                partNumbers.add(part.Part_Number__c);
                partKeys.add(part.Name + ':' + part.Part_Number__c); // Unique key = Name + Part Number
            }
        }
        
        // Query existing Product2 records that match part names and numbers
        for (Product2 prod : [
            SELECT Id, Name, ProductCode
            FROM Product2
            WHERE Name IN :partNames AND ProductCode IN :partNumbers
        ]) {
            // Build unique key and add to map
            String key = prod.Name + ':' + prod.ProductCode;
            partKeyToProductMap.put(key, prod);
        }
        
        // Loop through each Part to determine whether to link or create Product
        for (SQX_Part__c part : parts) {
            String key = part.Name + ':' + part.Part_Number__c;
            
            if (partKeyToProductMap.containsKey(key)) {
                // If matching product exists, link it to the part
                part.Product__c = partKeyToProductMap.get(key).Id;
                partsToUpdate.add(part);
            } else {
                // Else, prepare to create a new Product
                Product2 newProd = new Product2(
                    Name = part.Name,
                    ProductCode = part.Part_Number__c,
                    IsActive = true
                );
                newProducts.add(newProd);
            }
        }
        
        // Insert any new Product2 records and Handling insert of new Product
        if (!newProducts.isEmpty()) {
            try {
                
                insert newProducts;
                
            } catch (DmlException e) {
                
                System.debug('DML Exception while inserting Products: ' + e.getMessage());
                
                return; // Exit execution to prevent cascading failure
                
            }
            
            // Add newly created Products to the map using same key logic
            for (Product2 p : newProducts) {
                String key = p.Name + ':' + p.ProductCode;
                partKeyToProductMap.put(key, p);
            }
            
            // Re-loop through Parts to assign Product__c from newly created Products
            for (SQX_Part__c part : parts) {
                String key = part.Name + ':' + part.Part_Number__c;
                
                if (partKeyToProductMap.containsKey(key)) {
                    part.Product__c = partKeyToProductMap.get(key).Id;
                    partsToUpdate.add(part);
                }
            }
        }
        
        // Update all Parts with linked Product references and handling update of Part
        if (!partsToUpdate.isEmpty()) {
            try {
                
                update partsToUpdate;
                
            } catch (DmlException e) {
                
                System.debug('DML Exception while updating Parts: ' + e.getMessage());
                
                // Optionally handle partial failures or log to custom object
                
            }
        }
    }
    
    // Finish method: called after all batches complete
    global void finish(Database.BatchableContext bc) {
        System.debug('Part to Product batch completed.');
    }
}