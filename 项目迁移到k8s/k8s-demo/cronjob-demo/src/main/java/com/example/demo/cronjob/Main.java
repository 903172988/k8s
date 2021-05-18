package com.example.demo.cronjob;

import java.util.Random;

public class Main {

    public static void main(String[] args) {

        Random r = new Random();
        int time = r.nextInt(20) + 10;
        System.out.println("I will working for " + time + " seconds!");

        try {
            Thread.sleep(time * 1000);
        } catch (Exception e) {
            e.printStackTrace();
        }
        System.out.println("All work is done! Bye!");
    }
}
