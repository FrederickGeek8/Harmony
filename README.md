# Harmony
An open-source "clone" of [Duet Display](https://www.duetdisplay.com/)... or at least thats what I want it to be. The aim of this project is to create a mirrored macOS display on your iPad which can be interacted with to create a high-end Wacom like experience.

## A Story (What Works and What Doesn't Work)
This is a project that desperately needs help from engineers of all backgrounds. Right now mouse-pointer integration is complete (the easy part), however mirroring the display of the computer is not done, and perhaps will never be done.

### The Problem
Fitting an uncompressed, full-sized TIFF of a Retina display down any size pipe in real-time is damn near impossible. What needs to be done is down-scaling and compression, however that is something that is best executed on the GPU, something that I do not have experience dappling in.

In short, I need help. Lots of help. This project needs help. If there is anything you can contribute please do. Even if its just advice and a new direction for the project to move in.

## Contributing
Any contributions are welcome. I have commented out the initialization code for the screen-mirroring technologies so that those who are just interested in the mouse-pointer capabilities may use this project to their heart's content.

## Further Reading
[Inside DuetDisplay and Unattributed Open-Source](http://ich.deanmcnamee.com/re/2014/12/18/DuetDisplay.html)
