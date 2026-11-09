# Submission

Fork URL: <!-- paste the URL of your fork here -->

## Files to commit

- [ ] `Dockerfile`: your production Dockerfile, committed to the repo

## Questions

Answer in your own words. Where a question asks for output, paste it in a code block.

### Q1. The naive image: paste its size (`docker images pollie:naive`), the user it runs as, and how long a rebuild took after you changed one line of source code. What made the rebuild slow?

**Your answer:**

<!-- replace this line with your answer -->

### Q2. Paste `docker history pollie:naive` and name the two biggest layers. What is in each one, and which of the two could you avoid shipping at all?

**Your answer:**

<!-- replace this line with your answer -->

### Q3. Explain, instruction by instruction, why your Dockerfile copies `requirements.txt` and installs dependencies *before* copying the source code. Paste the build output lines that show the install step served from the cache.

**Your answer:**

<!-- replace this line with your answer -->

### Q4. Your image runs both the API and the worker. How do you choose which one starts, and what is the benefit of one image over two? The worker container shows `unhealthy` in `docker ps`: why, and how can you fix that without changing the image?

**Your answer:**

<!-- replace this line with your answer -->

### Q5. You stopped `ship-redis` while your API container was running. Paste `/healthz` and `/readyz` during the outage and after it. Why does the container stay "healthy" while `/readyz` fails, and what should an orchestrator do in each case?

**Your answer:**

<!-- replace this line with your answer -->

### Q6. Why does the image not contain `DATABASE_URL`? Where did the value come from when you ran it? Why is `FROM python:latest` a bad idea, and what tag would you give your image in a pipeline?

**Your answer:**

<!-- replace this line with your answer -->

### Q7. Paste the output of `./verify.sh`. It must end with **ALL CHECKS PASSED**.

**Your answer:**

<!-- replace this line with your answer -->

### Q8. **Tear down.** Paste the output of `./verify-teardown.sh`. It must end with **TEARDOWN VERIFIED**.

**Your answer:**

<!-- replace this line with your answer -->
