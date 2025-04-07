# Queries, Infinite Queries, and Mutations

Learn about the different paradigms of fetching and managing data with the library, and how you can even create your own paradigms using the tools in the library.

## Overview

The library provides 3 query paradigms that are applicable to different situations:

1. **Queries**: The most basic paradigm that supports fetching any kind of data.
2. **Infinite Queries**: A paradigm for fetching paginated data that can be put into an infinite scrollable list piece by piece.
3. **Mutations**: A paradigm for updating data asynchronously, such as performing a POST request to an API.

Infinite queries and mutations are both built directly on top of ordinary queries, and so all modifiers and functionallity that works with traditional queries will also work with those 2 paradigms.

Let's dive into the basics of each paradigm, and even show an example how you can create your own paradigm.
