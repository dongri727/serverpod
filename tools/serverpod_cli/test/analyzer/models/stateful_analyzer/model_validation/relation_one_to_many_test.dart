import 'package:serverpod_cli/src/analyzer/models/definitions.dart';
import 'package:serverpod_cli/src/analyzer/models/stateful_analyzer.dart';
import 'package:serverpod_cli/src/generator/code_generation_collector.dart';
import 'package:serverpod_cli/src/test_util/builders/model_source_builder.dart';
import 'package:test/test.dart';

void main() {
  group('Given a class with a one to many relation', () {
    var protocols = [
      ModelSourceBuilder().withFileName('employee').withYaml(
        '''
        class: Employee
        table: employee
        fields:
          company: Company?, relation(name=company_employees)
        ''',
      ).build(),
      ModelSourceBuilder().withFileName('company').withYaml(
        '''
        class: Company
        table: company
        fields:
          employees: List<Employee>?, relation(name=company_employees)
        ''',
      ).build()
    ];

    var collector = CodeGenerationCollector();
    StatefulAnalyzer analyzer = StatefulAnalyzer(
      protocols,
      onErrorsCollector(collector),
    );
    var definitions = analyzer.validateAll();
    var classDefinition = definitions
        .whereType<ClassDefinition>()
        .firstWhere((d) => d.className == 'Company');

    var errors = collector.errors;

    test('then no errors are collected.', () {
      expect(errors, isEmpty);
    });

    test('then no id field was created for the many side.', () {
      expect(
        classDefinition.findField('employeesId'),
        isNull,
        reason: 'Expected employeesId to not exist as a field, but it did.',
      );
    }, skip: errors.isNotEmpty);

    var relation = classDefinition.findField('employees')?.relation;
    test('then the reference field is set on the list relation.', () {
      expect(relation.runtimeType, ListRelationDefinition);
      expect(
        (relation as ListRelationDefinition).foreignFieldName,
        'companyId',
        reason: 'Expected the reference field to be set to "companyId".',
      );
    }, skip: errors.isNotEmpty);

    test('then the foreign field name is set on the list relation.', () {
      expect(relation.runtimeType, ListRelationDefinition);
      expect(
        (relation as ListRelationDefinition).fieldName,
        'id',
        reason: 'Expected the reference field to be set to "id".',
      );
    }, skip: errors.isNotEmpty);

    test('then the implicit field is false.', () {
      expect(relation.runtimeType, ListRelationDefinition);
      expect(
        (relation as ListRelationDefinition).implicitForeignField,
        isFalse,
        reason: 'Expected implicit field to be false.',
      );
    }, skip: errors.isNotEmpty);

    test('has the nullableRelation set to false', () {
      expect((relation as ListRelationDefinition).nullableRelation, false);
    }, skip: relation is! ListRelationDefinition);
  });

  group(
      'Given two classes with one to many relations defined without specifying a name',
      () {
    var protocols = [
      ModelSourceBuilder().withFileName('employee').withYaml(
        '''
        class: Employee
        table: employee
        fields:
          company: Company?, relation
        ''',
      ).build(),
      ModelSourceBuilder().withFileName('company').withYaml(
        '''
        class: Company
        table: company
        fields:
          employees: List<Employee>?, relation
        ''',
      ).build(),
    ];

    var collector = CodeGenerationCollector();
    var analyzer = StatefulAnalyzer(protocols, onErrorsCollector(collector));
    var definitions = analyzer.validateAll();

    var employeeDefinition = definitions.first as ClassDefinition;
    var companyDefinition = definitions.last as ClassDefinition;

    var errors = collector.errors;

    group('then two independent relations are created', () {
      test('with no errors during validation.', () {
        expect(errors, isEmpty);
      });

      test('with no id field was created for the many side.', () {
        expect(
          companyDefinition.findField('employeesId'),
          isNull,
          reason: 'Expected employeesId to not exist as a field, but it did.',
        );
      });

      test(
          'with the reference field is set on the list relation to an implicit relation field.',
          () {
        var relation = companyDefinition.findField('employees')?.relation;

        expect(relation.runtimeType, ListRelationDefinition);
        expect(
          (relation as ListRelationDefinition).foreignFieldName,
          '_companyEmployeesCompanyId',
          reason: 'Expected the reference field to be set.',
        );
      });

      test('with the foreign field name set on the list relation.', () {
        var relation = companyDefinition.findField('employees')?.relation;

        expect(relation.runtimeType, ListRelationDefinition);
        expect(
          (relation as ListRelationDefinition).fieldName,
          'id',
          reason: 'Expected the reference field to be set.',
        );
      });

      test('with the is implicit flag set to true on the list relation.', () {
        var relation = companyDefinition.findField('employees')?.relation;

        expect(relation.runtimeType, ListRelationDefinition);
        expect(
          (relation as ListRelationDefinition).implicitForeignField,
          isTrue,
          reason: 'Expected implicit field is true.',
        );
      });

      test('with the relation field created on the employee side.', () {
        var field = employeeDefinition.findField(
          '_companyEmployeesCompanyId',
        );

        expect(field, isNotNull);
      });

      test('with the relation field created with scope none on employee side.',
          () {
        var field = employeeDefinition.findField(
          '_companyEmployeesCompanyId',
        );

        expect(field?.scope, ModelFieldScopeDefinition.none);
      });

      test(
          'with the reference field is set on the object relation to an implicit relation field.',
          () {
        var relation = employeeDefinition.findField('company')?.relation;

        expect(relation.runtimeType, ObjectRelationDefinition);
        expect(
          (relation as ObjectRelationDefinition).fieldName,
          'companyId',
          reason: 'Expected the reference field to be set.',
        );
      });

      test('with the companyId relation field created on the employee side.',
          () {
        expect(employeeDefinition.findField('companyId'), isNotNull);
      });
    });
  });

  test(
      'Given a class with a one to many relation where the relation ship is ambiguous then an error is collected that the reference cannot be resolved.',
      () {
    var protocols = [
      ModelSourceBuilder().withFileName('employee').withYaml(
        '''
        class: Employee
        table: employee
        fields:
          company: Company?, relation(name=company_employees)
          myCompany: Company?, relation(name=company_employees)
        ''',
      ).build(),
      ModelSourceBuilder().withFileName('company').withYaml(
        '''
        class: Company
        table: company
        fields:
          employees: List<Employee>?, relation(name=company_employees)
        ''',
      ).build(),
    ];

    var collector = CodeGenerationCollector();
    var analyzer = StatefulAnalyzer(protocols, onErrorsCollector(collector));
    analyzer.validateAll();

    expect(
      collector.errors,
      isNotEmpty,
      reason: 'Expected an error but none was found.',
    );

    var error = collector.errors.first;

    expect(
      error.message,
      'Unable to resolve ambiguous relation, there are several named relations with name "company_employees" on the class "Employee".',
    );
  });

  group(
      'Given a class with a one to many relation where the relationship is only named on one side',
      () {
    var protocols = [
      ModelSourceBuilder().withFileName('employee').withYaml(
        '''
        class: Employee
        table: employee
        fields:
          company: Company?, relation
        ''',
      ).build(),
      ModelSourceBuilder().withFileName('company').withYaml(
        '''
        class: Company
        table: company
        fields:
          employees: List<Employee>?, relation(name=company_employees)
        ''',
      ).build(),
    ];

    var collector = CodeGenerationCollector();
    var analyzer = StatefulAnalyzer(protocols, onErrorsCollector(collector));
    analyzer.validateAll();

    var errors = collector.errors;

    test('then an error is collected', () {
      expect(errors, isNotEmpty);
    });

    test(
        'then the error messages says that there must be a named relation on the other side.',
        () {
      expect(
        errors.first.message,
        'There is no named relation with name "company_employees" on the class "Employee".',
      );
    }, skip: errors.isEmpty);
  });

  group(
      'Given a class with a one to many relation where the relationship is named with a none string value',
      () {
    var protocols = [
      ModelSourceBuilder().withFileName('employee').withYaml(
        '''
        class: Employee
        table: employee
        fields:
          company: 
            type: Company?
            relation:
              name: 1
        ''',
      ).build(),
      ModelSourceBuilder().withFileName('company').withYaml(
        '''
        class: Company
        table: company
        fields:
          employees: 
            type: List<Employee>?
            relation:
              name: 1
        ''',
      ).build(),
    ];

    var collector = CodeGenerationCollector();
    var analyzer = StatefulAnalyzer(protocols, onErrorsCollector(collector));
    analyzer.validateAll();

    var errors = collector.errors;

    test('then an error is collected', () {
      expect(errors, isNotEmpty);
    });

    test('then the error messages says the value must be a string.', () {
      expect(
        errors.first.message,
        'The property must be a String.',
      );
    }, skip: errors.isEmpty);
  });

  group('Given an implicit one to many relation', () {
    var protocols = [
      ModelSourceBuilder().withFileName('employee').withYaml(
        '''
        class: Employee
        table: employee
        fields:
          name: String
        ''',
      ).build(),
      ModelSourceBuilder().withFileName('company').withYaml(
        '''
        class: Company
        table: company
        fields:
          employees: List<Employee>?, relation
        ''',
      ).build(),
    ];

    var collector = CodeGenerationCollector();
    var analyzer = StatefulAnalyzer(protocols, onErrorsCollector(collector));
    var definitions = analyzer.validateAll();

    var employeeDefinition = definitions.first as ClassDefinition;
    var companyDefinition = definitions.last as ClassDefinition;

    test('then no errors are collected.', () {
      expect(collector.errors, isEmpty);
    });

    var relation = companyDefinition.findField('employees')?.relation;
    test('then the reference field is set on the list relation.', () {
      expect(relation.runtimeType, ListRelationDefinition);
      expect(
        (relation as ListRelationDefinition).foreignFieldName,
        '_companyEmployeesCompanyId',
        reason: 'Expected the reference field to be set.',
      );
    });

    test('has the nullableRelation set to true', () {
      expect((relation as ListRelationDefinition).nullableRelation, true);
    }, skip: relation is! ListRelationDefinition);

    test('then the relation field is created on the employee side.', () {
      var field = employeeDefinition.findField('_companyEmployeesCompanyId');

      expect(field, isNotNull);
    });
  });

  group(
      'Given an implicit one to many relation with many table including underscores',
      () {
    var protocols = [
      ModelSourceBuilder().withFileName('employee').withYaml(
        '''
        class: Employee
        table: employee
        fields:
          name: String
        ''',
      ).build(),
      ModelSourceBuilder().withFileName('company').withYaml(
        '''
        class: Company
        table: company_table
        fields:
          employees: List<Employee>?, relation
        ''',
      ).build(),
    ];

    var collector = CodeGenerationCollector();
    var analyzer = StatefulAnalyzer(protocols, onErrorsCollector(collector));
    var definitions = analyzer.validateAll();

    var employeeDefinition = definitions.first as ClassDefinition;
    var companyDefinition = definitions.last as ClassDefinition;

    test('then no errors are collected.', () {
      expect(collector.errors, isEmpty);
    });

    var relation = companyDefinition.findField('employees')?.relation;
    test(
        'then the table name in the reference field on the list relation is converted to camel case.',
        () {
      expect(relation.runtimeType, ListRelationDefinition);
      expect(
        (relation as ListRelationDefinition).foreignFieldName,
        '_companyTableEmployeesCompanyTableId',
        reason: 'Expected the reference field to be set.',
      );
    });

    test(
        'then the table name in the relation field on the employee side is converted to camel case.',
        () {
      var field =
          employeeDefinition.findField('_companyTableEmployeesCompanyTableId');

      expect(field, isNotNull);
    });
  });

  group(
      'Given a named list relation protocol ordered before the primary key protocol, when parsing the protocols',
      () {
    var protocols = [
      ModelSourceBuilder().withFileName('customer').withYaml(
        '''
        class: Customer
        table: customer
        fields:
          name: String
          orders: List<Order>?, relation(name=customer_order)
        ''',
      ).build(),
      ModelSourceBuilder().withFileName('order').withYaml(
        '''
        class: Order
        table: order
        fields:
          description: String
          customerId: int
          customer: Customer?, relation(name=customer_order, field=customerId)
        ''',
      ).build(),
    ];

    var collector = CodeGenerationCollector();
    StatefulAnalyzer analyzer = StatefulAnalyzer(
      protocols,
      onErrorsCollector(collector),
    );
    var definitions = analyzer.validateAll();
    var classDefinition = definitions
        .whereType<ClassDefinition>()
        .firstWhere((d) => d.className == 'Customer');

    var errors = collector.errors;

    test('then no errors are collected.', () {
      expect(errors, isEmpty);
    });

    test('then customer has list orders field', () {
      expect(classDefinition.findField('orders'), isNotNull);
    });

    test('then orders is list relation', () {
      expect(classDefinition.findField('orders')?.relation.runtimeType,
          ListRelationDefinition);
    });
  });

  group(
      'Given an unnamed list relation protocol linked to another protocol with an unname object relation, when parsing the protocols',
      () {
    var protocols = [
      ModelSourceBuilder().withFileName('customer').withYaml(
        '''
        class: Customer
        table: customer
        fields:
          name: String
          orders: List<Order>?, relation
        ''',
      ).build(),
      ModelSourceBuilder().withFileName('order').withYaml(
        '''
        class: Order
        table: order
        fields:
          description: String
          customerId: int
          customer: Customer?, relation(field=customerId)
        ''',
      ).build(),
    ];

    var collector = CodeGenerationCollector();
    StatefulAnalyzer analyzer = StatefulAnalyzer(
      protocols,
      onErrorsCollector(collector),
    );
    var definitions = analyzer.validateAll();
    var classDefinition = definitions
        .whereType<ClassDefinition>()
        .firstWhere((d) => d.className == 'Customer');

    var errors = collector.errors;

    test('then no errors are collected.', () {
      expect(errors, isEmpty);
    });

    test('then customer has list orders field', () {
      expect(classDefinition.findField('orders'), isNotNull);
    });

    test('then orders is list relation', () {
      expect(classDefinition.findField('orders')?.relation.runtimeType,
          ListRelationDefinition);
    });

    test('then the list relation is NOT linked with the customerId field', () {
      var relation = classDefinition.findField('orders')?.relation
          as ListRelationDefinition;

      expect(relation.foreignFieldName, isNot('customerId'));
    });
  });

  group('Given a class with a one to many relation on a foreign key field', () {
    var protocols = [
      ModelSourceBuilder().withFileName('employee').withYaml(
        '''
        class: Employee
        table: employee
        fields:
          companyId: int, relation(name=company_employees, parent=company)
        ''',
      ).build(),
      ModelSourceBuilder().withFileName('company').withYaml(
        '''
        class: Company
        table: company
        fields:
          employees: List<Employee>?, relation(name=company_employees)
        ''',
      ).build()
    ];

    var collector = CodeGenerationCollector();
    StatefulAnalyzer analyzer = StatefulAnalyzer(
      protocols,
      onErrorsCollector(collector),
    );
    var definitions = analyzer.validateAll();
    var employeeDefinition = definitions
        .whereType<ClassDefinition>()
        .firstWhere((d) => d.className == 'Employee');
    var companyDefinition = definitions
        .whereType<ClassDefinition>()
        .firstWhere((d) => d.className == 'Company');

    var errors = collector.errors;

    test('then no errors are collected.', () {
      expect(errors, isEmpty);
    });

    test('then the employee relation is set', () {
      var relation = employeeDefinition.findField('companyId')?.relation;

      expect(relation?.name, 'company_employees');
      expect(relation.runtimeType, ForeignRelationDefinition);
    });

    test('then the company relation is set', () {
      var relation = companyDefinition.findField('employees')?.relation;

      expect(relation?.name, 'company_employees');
      expect(relation.runtimeType, ListRelationDefinition);
    });
  });
}
