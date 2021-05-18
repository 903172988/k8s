package com.example.demo.controller;

import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class DemoController {

    @RequestMapping("/hello")
    public String sayHello(@RequestParam String name) {
        return "Hello " + name + "! I'm springboot-web-demo controller!";
    }
}
