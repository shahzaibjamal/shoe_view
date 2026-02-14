import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shoe_view/Helpers/shoe_query_utils.dart';

class ShoeConditionPicker extends StatelessWidget {
  final String selectedCondition;
  final bool isLoading;
  final void Function(String) onConditionSelected;

  const ShoeConditionPicker({
    super.key,
    required this.selectedCondition,
    required this.isLoading,
    required this.onConditionSelected,
  });

  Future<void> _showPicker(BuildContext context) async {
    String tempSelected = selectedCondition;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('Select Condition', style: Theme.of(context).textTheme.titleMedium),
              ),
              SizedBox(
                height: 200,
                child: CupertinoPicker.builder(
                  scrollController: FixedExtentScrollController(
                    initialItem: ShoeQueryUtils.conditionList.indexOf(
                      selectedCondition,
                    ),
                  ),
                  itemExtent: 32.0,
                  onSelectedItemChanged: (int index) {
                    tempSelected = ShoeQueryUtils.conditionList[index];
                  },
                  childCount: ShoeQueryUtils.conditionList.length,
                  itemBuilder: (context, index) =>
                      Center(child: Text(
                        ShoeQueryUtils.conditionList[index], 
                        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)
                      )),
                ),
              ),
              TextButton(
                onPressed: () {
                  onConditionSelected(tempSelected);
                  Navigator.pop(context);
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : () => _showPicker(context),
      child: Card(
        child: ListTile(
          title: const Text('Condition (1.0 - 10.0)'),
          trailing: Text(selectedCondition),
        ),
      ),
    );
  }
}
