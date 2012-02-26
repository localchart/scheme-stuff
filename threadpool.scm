(use srfi-18)
(use data-structures)

(define (vector-map! f v)
  (let loop ((i 0))
    (when (< i (vector-length v))
      (vector-set! v i (f (vector-ref v i)))
      (loop (+ i 1)))))

(define (make-threadpool n)
  (let ((threads '#())
        (mutex (make-mutex))
        (queue (make-queue))
        (terminate? #f))
    (letrec ((threadpool-worker (lambda ()
               (let loop ()
                 (mutex-lock! mutex)
                 (cond ((not (queue-empty? queue))
                        (let ((task (queue-remove! queue))) 
                          (when (procedure? task)
                            (mutex-unlock! mutex)
                            (task))))
                       (else (mutex-unlock! mutex)))
                 (if (not terminate?)
                   (loop)
                   (begin
                     (mutex-unlock! mutex)
                     (thread-terminate! (current-thread))))))))
      (set! threads (make-vector n))
      (vector-map! (lambda (t)
                     (thread-start! (make-thread threadpool-worker)))
                   threads)
      (lambda (msg . args)
        (case msg
          ((has-workers?) (not (eq? (vector-length threads) 0)))
          ((has-tasks?) (not (queue-empty? queue)))
          ((execute!) (queue-add! queue (car args)))
          ((terminate!) (set! terminate? #t))
          ((terminated?) (let loop ((i 0))
                           (if (< i (vector-length threads))
                             (if (eq? (thread-state (vector-ref threads i)) 'terminated)
                               (loop (+ i 1))
                               #f)
                             #t)))
          ((populate!) (begin
                         (set! terminate? #f)
                         (set! threads (make-vector (car args)))
                         (vector-map! (lambda (t)
                                        (thread-start! (make-thread threadpool-worker)))
                                      threads))))))))

(define (threadpool-execute! tp thunk)
  (tp 'execute! thunk))

(define (threadpool-terminate! tp)
  (tp 'terminate!))

(define (threadpool-terminated? tp)
  (tp 'terminated?))

(define (threadpool-populate! tp n)
  (tp 'populate! n))

(define (threadpool-has-workers? tp)
  (tp 'has-workers?))

(define (threadpool-has-tasks? tp)
  (tp 'has-tasks?))

(define (threadpool-repopulate! tp n)
  (tp 'terminate!)
  (let loop ()
    (if (not (tp 'terminated?))
      (loop)
      (tp 'populate! n))))

