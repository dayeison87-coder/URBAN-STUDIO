import { TestBed } from '@angular/core/testing';

import { Barberos } from './barberos';

describe('Barberos', () => {
  let service: Barberos;

  beforeEach(() => {
    TestBed.configureTestingModule({});
    service = TestBed.inject(Barberos);
  });

  it('should be created', () => {
    expect(service).toBeTruthy();
  });
});
