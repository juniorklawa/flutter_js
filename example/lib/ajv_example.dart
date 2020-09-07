import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_js/flutter_js.dart';
import 'ajv_result_screen.dart';
import 'form.dart';

class AjvExample extends StatefulWidget {
  final JavascriptRuntime jsRuntime;
  AjvExample(this.jsRuntime, {Key key}) : super(key: key);

  _AjvExampleState createState() => _AjvExampleState();
}

class _AjvExampleState extends State<AjvExample> {
  String _jsResult = '';

  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();
  GlobalKey<FormState> _formKey = GlobalKey();
  GlobalKey<FormWidgetState> _formWidgetKey = GlobalKey();

  Future<dynamic> _loadingFuture;

  @override
  void initState() {
    super.initState();
    _loadingFuture = initJsEngine();
  }

// Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initJsEngine() async {
    try {
      String ajvJS = await rootBundle.loadString("assets/js/ajv.js");

      widget.jsRuntime.evaluate("var window = global = globalThis;");

      await widget.jsRuntime.evaluateAsync(ajvJS + "");
      final evalAjv = widget.jsRuntime.evaluate("""
                    var ajv = new global.Ajv({ allErrors: true, coerceTypes: true });
                    ajv.addSchema(
                      {
                        required: ["name", "age","id", "email", "student", "worker"], 
                        "properties": {
                          "id": {
                            "minimum": 0,
                            "type": "number" 
                          },
                          "name": {
                            "type": "string" 
                          },
                          "email": {
                            "type": "string",
                            "format": "email"
                          },
                          "age": {
                            "minimum": 0,
                            "type": "number" 
                          },
                          "student": {
                            "type": "boolean"
                          },
                          "worker": {
                            "type": "boolean"
                          }
                     
                        }
                    }, "obj1");
      """);
    } on PlatformException catch (e) {
      print('Failed to init js engine: ${e.details}');
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;
  }

  _validateFunctionFor() {
    return (String field, String valor, Map<String, String> data) {
      var formData = {};
      formData.addAll(data);
      formData.removeWhere((key, value) => value.toString().trim().isEmpty);
      if (valor != null && valor.length > 0) {
        formData[field] = valor;
      }
      final expression = """ajv.validate(
                         "obj1",
                         ${json.encode(formData)}
                         );
                         JSON.stringify(ajv.errors);
                         """;
      JsEvalResult jsResult = widget.jsRuntime.evaluate(expression);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _jsResult = jsResult.stringResult;
        });
      });

      final valueResult = json.decode(jsResult.stringResult);
      final List<ValidationResult> result =
          ValidationResult.listFromJson(valueResult is int ? [] : valueResult);

      final errorsForField = result
          .where((element) =>
              element.message.contains("$field") ||
              element.params['missingProperty'] == field ||
              element.dataPath == ".$field")
          .toList();

      return errorsForField;
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Ajv Example'),
      ),
      body: FutureBuilder(
        future: _loadingFuture,
        builder: (_, snapshot) =>
            snapshot.connectionState == ConnectionState.waiting
                ? Center(child: Text('Aguarde...'))
                : SingleChildScrollView(
                    child: Column(
                      children: <Widget>[
                        FormWidget(
                            operation: FormWidgetOperation.New,
                            formWidgetKey: _formWidgetKey,
                            formKey: _formKey,
                            validateFunction: _validateFunctionFor(),
                            fields: [
                              'id',
                              'name',
                              'email',
                              'age',
                              "student",
                              "worker"
                            ]),
                      ],
                    ),
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.info_outline),
        onPressed: () async {
          Navigator.of(_scaffoldKey.currentContext).push(
            MaterialPageRoute(
              builder: (context) => AjvResultScreen(
                "{\"errors\": ${_jsResult == "" ? null : _jsResult}}",
                notRoot: false,
              ),
            ),
          );
        },
      ),
    );
  }
}
