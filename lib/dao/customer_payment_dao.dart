import '../db/database_helper.dart';
import '../models/customer_payment.dart';

class CustomerPaymentDao {
  final dbHelper = DatabaseHelper();

  Future<int> insert(CustomerPayment payment) async =>
      await dbHelper.insert("customer_payments", payment.toMap());

  Future<List<CustomerPayment>> getByCustomerId(String customerId) async {
    final data = await dbHelper.queryWhere("customer_payments", "customer_id = ?", [customerId]);
    return data.map((e) => CustomerPayment.fromMap(e)).toList();
  }

  Future<int> update(CustomerPayment payment) async =>
      await dbHelper.update("customer_payments", payment.toMap(), payment.id);

  Future<int> delete(String id) async => await dbHelper.delete("customer_payments", id);
}
