import 'package:app_fitness/view/main_tab/select_view.dart';
import 'package:flutter/material.dart';

import '../../common/color_extension.dart';
import '../../common_widget/tab_button.dart';
import '../home/home_view.dart';
import '../profile/profile_view.dart';

class MainTabView extends StatefulWidget {
  const MainTabView({super.key});

  @override
  State<MainTabView> createState() => _MainTabViewState();
}

class _MainTabViewState extends State<MainTabView> {
  int selectTab = 0;
  final PageStorageBucket pageBucket = PageStorageBucket();
  Widget currentTab = const HomeView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TColor.white,
      body: PageStorage(bucket: pageBucket, child: currentTab),
      bottomNavigationBar: Container(

        decoration: BoxDecoration(
          color: TColor.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        height: 56, // <-- reduced height
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildTabButton(0, "assets/img/home_tab.png", "assets/img/home_tab_select.png", const HomeView()),
            _buildTabButton(1, "assets/img/activity_tab.png", "assets/img/activity_tab_select.png", const SelectView()),
            _buildTabButton(3, "assets/img/profile_tab.png", "assets/img/profile_tab_select.png", const ProfileView()),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String icon, String selectIcon, Widget view) {
    return Expanded(
      child: InkWell(
        onTap: () {
          selectTab = index;
          currentTab = view;
          if (mounted) setState(() {});
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TabButton(
              icon: icon,
              selectIcon: selectIcon,
              isActive: selectTab == index,
              onTap: () {
                selectTab = index;
                currentTab = view;
                if (mounted) setState(() {});
              },
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 6,
              width: selectTab == index ? 48 : 0,
              decoration: BoxDecoration(
                color: selectTab == index ? Colors.black : Colors.transparent,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}