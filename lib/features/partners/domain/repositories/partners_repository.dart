import 'package:dartz/dartz.dart';
import '../entities/business_field.dart';
import '../entities/client.dart';
import '../entities/client_field.dart';
import '../entities/supplier.dart';
import '../entities/supplier_field.dart';

abstract class PartnersRepository {
  Future<Either<Exception, List<BusinessField>>> getBusinessFields();
  Future<Either<Exception, List<BusinessField>>> getSupplierFieldDefinitions();
  Future<Either<Exception, BusinessField>> createSupplierBusinessField({
    required String nameAr,
    String? nameEn,
    String? description,
  });
  Future<Either<Exception, BusinessField>> createClientBusinessField({
    required String nameAr,
    String? nameEn,
    String? description,
  });
  Future<Either<Exception, List<Client>>> getClients();
  Future<Either<Exception, List<Supplier>>> getSuppliers();
  Future<Either<Exception, List<ClientField>>> getClientFields(String clientId);
  Future<Either<Exception, List<SupplierField>>> getSupplierFields(String supplierId);
  Future<Either<Exception, bool>> updateClientFields({
    required String clientId,
    required List<String> fieldIds,
  });
  Future<Either<Exception, Client>> createClient({
    required String name,
    String? phone,
    String? email,
    String? address,
    String? taxNumber,
    String? notes,
    bool isActive = true,
    num balance = 0,
  });
  Future<Either<Exception, Supplier>> createSupplier({
    required String name,
    String? phone,
    String? email,
    String? address,
    String? taxNumber,
    String? notes,
    bool isActive = true,
    num balance = 0,
  });
  Future<Either<Exception, Client>> updateClient({
    required String id,
    required String name,
    String? phone,
    String? email,
    String? address,
    String? taxNumber,
    String? notes,
    bool? isActive,
    num? balance,
  });
  Future<Either<Exception, bool>> updateSupplierFields({
    required String supplierId,
    required List<String> fieldIds,
  });
  Future<Either<Exception, Supplier>> updateSupplier({
    required String id,
    required String name,
    String? phone,
    String? email,
    String? address,
    String? taxNumber,
    String? notes,
    bool? isActive,
    num? balance,
  });
  Future<Either<Exception, bool>> deleteSupplier(String id);
}
