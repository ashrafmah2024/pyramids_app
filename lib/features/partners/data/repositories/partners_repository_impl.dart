import 'package:dartz/dartz.dart';
import '../datasources/partners_remote_data_source.dart';
import '../../domain/entities/business_field.dart';
import '../../domain/entities/client.dart';
import '../../domain/entities/client_field.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/entities/supplier_field.dart';
import '../../domain/repositories/partners_repository.dart';

class PartnersRepositoryImpl implements PartnersRepository {
  final PartnersRemoteDataSource remote;
  PartnersRepositoryImpl(this.remote);

  @override
  Future<Either<Exception, List<BusinessField>>> getBusinessFields() async {
    try {
      final data = await remote.getBusinessFields();
      return Right(data);
    } catch (e) {
      return Left(Exception('Failed to get business fields: $e'));
    }
  }

  @override
  Future<Either<Exception, BusinessField>> createClientBusinessField({
    required String nameAr,
    String? nameEn,
    String? description,
  }) async {
    try {
      final created = await remote.createClientBusinessField(
        nameAr: nameAr,
        nameEn: nameEn,
        description: description,
      );
      return Right(created);
    } catch (e) {
      return Left(Exception('Failed to create client business field: $e'));
    }
  }

  @override
  Future<Either<Exception, List<BusinessField>>> getSupplierFieldDefinitions() async {
    try {
      final data = await remote.getSupplierFieldDefinitions();
      return Right(data);
    } catch (e) {
      return Left(Exception('Failed to get supplier field definitions: $e'));
    }
  }

  @override
  Future<Either<Exception, BusinessField>> createSupplierBusinessField({
    required String nameAr,
    String? nameEn,
    String? description,
  }) async {
    try {
      final created = await remote.createSupplierBusinessField(
        nameAr: nameAr,
        nameEn: nameEn,
        description: description,
      );
      return Right(created);
    } catch (e) {
      return Left(Exception('Failed to create supplier business field: $e'));
    }
  }

  @override
  Future<Either<Exception, List<Client>>> getClients() async {
    try {
      final data = await remote.getClients();
      return Right(data);
    } catch (e) {
      return Left(Exception('Failed to get clients: $e'));
    }
  }

  @override
  Future<Either<Exception, List<Supplier>>> getSuppliers() async {
    try {
      final data = await remote.getSuppliers();
      return Right(data);
    } catch (e) {
      return Left(Exception('Failed to get suppliers: $e'));
    }
  }

  @override
  Future<Either<Exception, List<ClientField>>> getClientFields(String clientId) async {
    try {
      final data = await remote.getClientFields(clientId);
      return Right(data);
    } catch (e) {
      return Left(Exception('Failed to get client fields: $e'));
    }
  }

  @override
  Future<Either<Exception, List<SupplierField>>> getSupplierFields(String supplierId) async {
    try {
      final data = await remote.getSupplierFields(supplierId);
      return Right(data);
    } catch (e) {
      return Left(Exception('Failed to get supplier fields: $e'));
    }
  }

  @override
  Future<Either<Exception, Client>> createClient({
    required String name,
    String? phone,
    String? email,
    String? address,
    String? taxNumber,
    String? notes,
    bool isActive = true,
    num balance = 0,
  }) async {
    try {
      final created = await remote.createClient(
        name: name,
        phone: phone,
        email: email,
        address: address,
        taxNumber: taxNumber,
        notes: notes,
        isActive: isActive,
        balance: balance,
      );
      return Right(created);
    } catch (e) {
      return Left(Exception('Failed to create client: $e'));
    }
  }

  @override
  Future<Either<Exception, Supplier>> createSupplier({
    required String name,
    String? phone,
    String? email,
    String? address,
    String? taxNumber,
    String? notes,
    bool isActive = true,
    num balance = 0,
  }) async {
    try {
      final created = await remote.createSupplier(
        name: name,
        phone: phone,
        email: email,
        address: address,
        taxNumber: taxNumber,
        notes: notes,
        isActive: isActive,
        balance: balance,
      );
      return Right(created);
    } catch (e) {
      return Left(Exception('Failed to create supplier: $e'));
    }
  }

  @override
  Future<Either<Exception, bool>> updateClientFields({
    required String clientId,
    required List<String> fieldIds,
  }) async {
    try {
      final ok = await remote.updateClientFields(clientId: clientId, fieldIds: fieldIds);
      return Right(ok);
    } catch (e) {
      return Left(Exception('Failed to update client fields: $e'));
    }
  }

  @override
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
  }) async {
    try {
      final updated = await remote.updateClient(
        id: id,
        name: name,
        phone: phone,
        email: email,
        address: address,
        taxNumber: taxNumber,
        notes: notes,
        isActive: isActive,
        balance: balance,
      );
      return Right(updated);
    } catch (e) {
      return Left(Exception('Failed to update client: $e'));
    }
  }

  @override
  Future<Either<Exception, bool>> updateSupplierFields({
    required String supplierId,
    required List<String> fieldIds,
  }) async {
    try {
      final ok = await remote.updateSupplierFields(supplierId: supplierId, fieldIds: fieldIds);
      return Right(ok);
    } catch (e) {
      return Left(Exception('Failed to update supplier fields: $e'));
    }
  }

  @override
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
  }) async {
    try {
      final updated = await remote.updateSupplier(
        id: id,
        name: name,
        phone: phone,
        email: email,
        address: address,
        taxNumber: taxNumber,
        notes: notes,
        isActive: isActive,
        balance: balance,
      );
      return Right(updated);
    } catch (e) {
      return Left(Exception('Failed to update supplier: $e'));
    }
  }

  @override
  Future<Either<Exception, bool>> deleteSupplier(String id) async {
    try {
      final ok = await remote.deleteSupplier(id);
      return Right(ok);
    } catch (e) {
      return Left(Exception('Failed to delete supplier: $e'));
    }
  }
}
