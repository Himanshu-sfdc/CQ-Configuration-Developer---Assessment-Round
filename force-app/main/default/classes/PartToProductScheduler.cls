global class PartToProductScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        // Call the batch class
        Database.executeBatch(new PartToProductBatch());
    }
}