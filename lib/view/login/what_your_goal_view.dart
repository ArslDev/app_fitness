import 'package:app_fitness/view/login/welcome_view.dart';
import 'package:carousel_slider/carousel_controller.dart';
import 'package:carousel_slider/carousel_slider.dart';

import 'package:flutter/material.dart';

import '../../common/color_extension.dart';
import '../../common_widget/round_button.dart';


class WhatYourGoalView extends StatefulWidget {
  const WhatYourGoalView({super.key});

  @override
  State<WhatYourGoalView> createState() => _WhatYourGoalViewState();
}

class _WhatYourGoalViewState extends State<WhatYourGoalView> {
  final List goalList = [
    {'image': "assets/img/goal_1.png", 'title': "Improve Shape" , 'subtitle': "Build strength and gain muscle with\nour expert guidance."},
    {'image': "assets/img/goal_2.png", 'title': "Lean & tone", 'subtitle': "Boost your stamina and endurance with\nour tailored workouts."},
    {'image': "assets/img/goal_3.png", 'title': "lose a fat", 'subtitle': "Get fit and lose weight with\nour personalized plans."},
  ];
  @override
  Widget build(BuildContext context) {
    var media = MediaQuery.of(context).size;
    CarouselSliderController buttonCarouselController = CarouselSliderController();
    return  Scaffold(
      backgroundColor: TColor.white,
      body: SafeArea(child: Stack(
        children: [
          Center(
            child: CarouselSlider(
              items: goalList.map((gobj) => Container(
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(vertical: media.width*0.1 , horizontal: 25),
                decoration: BoxDecoration(
                    gradient: LinearGradient(colors: TColor.primaryG,begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(20)
                ),child: FittedBox(
                child: Column(
                  children: [
                    Image.asset(gobj["image"].toString(), width: media.width * 0.5, fit: BoxFit.fitWidth,),
                    SizedBox(height: media.width * 0.07,),
                    Text(
                      gobj["title"].toString(),
                      style: TextStyle(color: TColor.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700),
                    ),
                    Container(
                      width: media.width * 0.1,
                      height: 1,
                      color: TColor.white,
                    ),
                    SizedBox(
                      height: media.width * 0.04,
                    ),
                    Text(
                      gobj["subtitle"].toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: TColor.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              )).toList(),
              carouselController: buttonCarouselController,
              options: CarouselOptions(
                autoPlay: false,
                enlargeCenterPage: true,
                viewportFraction: 0.8,
                aspectRatio: 0.75,
                initialPage: 0,
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 15),
            width: media.width,
            child: Column(
              children: [SizedBox(
                height: media.width* 0.05,
              ),
                Text(
                  "what's your goal?",
                  style: TextStyle(color: TColor.black,
                      fontSize: 20,
                      fontWeight: FontWeight.w700),
                ),

                Text(
                  "It will help us to choose the best\nplan for you!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: TColor.gray,
                    fontSize: 12,
                  ),
                ),
                Spacer(),
                SizedBox(
                  height: media.width * 0.05,
                ),
                RoundButton(title: "Confirm  ", onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const WelcomeView()  ));
                }),
              SizedBox(height: 10,)],
            ),
          )
        ],
      )),
    );
  }
}
